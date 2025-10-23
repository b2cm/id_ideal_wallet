import 'dart:convert';
import 'dart:io';

import 'package:base_codecs/base_codecs.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/api.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

const String localhost =
    "http://78.47.219.104:3000"; //"http://ec2-18-199-147-148.eu-central-1.compute.amazonaws.com:3000";//"http://10.0.2.2";
const String apiKey = 'supersecretapikey123';

Future<(Map<String, Map<String, dynamic>>, String)> getBackupableData() async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);
  var walletData = await wallet.wallet.export();
  var osKeyStoreDids = wallet.getDidsInOsKeyStore();
  String notInBackup = '';
  logger.d(walletData['credentials']?.length);
  for (var d in osKeyStoreDids ?? <String>[]) {
    logger.d(d);
    var c = walletData['credentials']?.remove(d);
    if (c != null) {
      logger.d(c);
      notInBackup += getTypeToShow(VerifiableCredential.fromJson(
              Credential.fromJson(c).verifiableCredential)
          .type);
      notInBackup += ', ';
    }
  }
  logger.d(walletData['credentials']?.length);
  return (walletData, notInBackup);
}

// Function to perform backup in background task
Future<bool> performBackup(Map<String, dynamic> input) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(input['token']);
  logger.d('backup start');
  Map<String, Map<String, dynamic>> data = input['data'];
  String memonic = input['mnemonic'];
  logger.d(memonic);
  logger.d(data['credentials']?.length);
  Uint8List password = getPasswordFromMnemonic(memonic);

  var encodedBoxes = jsonEncode(data);

  // Encrypt boxes
  final encryptedData = encryptData(encodedBoxes, password);

  // Save the file locally first
  File file =
      await saveFileLocally(hexEncode(sha256.process(password)), encryptedData);
  logger.d('local file saved');

  String apiUrl = '$localhost/data';
  String textData = hexEncode(sha256.process(password));

  return await sendStringAndFile(apiUrl, apiKey, textData, file);
}

Future<Map<String, Map<String, dynamic>>?> loadAndDecryptBackup(
    String mnemonic) async {
  Uint8List password = getPasswordFromMnemonic(mnemonic);

  try {
    var encryptedData =
        await fetchFileInMemory(hexEncode(sha256.process(password)));

    // Decrypt the data using the password
    String encodedBoxes = decryptData(password, encryptedData);
    logger.d('decrypted');

    var walletData = (jsonDecode(encodedBoxes) as Map).map((k, v) => MapEntry(
        k as String, (v as Map).map((k1, v1) => MapEntry(k1 as String, v1))));
    return walletData;
  } catch (e) {
    logger.d(e);
    return null;
  }
}

Future<bool> applyBackup(BuildContext context, String mnemonic) async {
  var wallet = Provider.of<WalletProvider>(context, listen: false);

  var walletData = await compute(loadAndDecryptBackup, mnemonic);
  if (walletData == null) {
    showErrorMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!.backupRestoreError,
      AppLocalizations.of(navigatorKey.currentContext!)!.backupRestoreErrorNote,
    );
    return false;
  }

  var cKeys = wallet.wallet.getAllCredentials().keys;
  for (var k in cKeys) {
    await wallet.wallet.deleteCredential(k);
  }
  logger.d(wallet.wallet.getAllCredentials().length);

  try {
    await wallet.wallet.import(walletData);
  } catch (e) {
    logger.d(e);
    showErrorMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!.backupRestoreError,
      AppLocalizations.of(navigatorKey.currentContext!)!.backupRestoreErrorNote,
    );
    return false;
  }

  await wallet.restart();
  Provider.of<NavigationProvider>(navigatorKey.currentContext!, listen: false)
      .goBack();

  showSuccessMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!.restoreSuccess);
  return true;
}

// Function to save the file on disk
Future<File> saveFileLocally(String fileName, String encryptedData) async {
  // Get the directory where to save the file (temporary directory in this case)
  final directory = await getTemporaryDirectory();

  // Create the file path
  final filePath = '${directory.path}/$fileName';

  // Create the file
  File file = File(filePath);

  // Write the encrypted data to the file
  return file.writeAsString(encryptedData);
}

Future<bool> sendStringAndFile(
    String apiUrl, String apiKey, String textData, File file) async {
  try {
    // Create the Multipart request
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

    // Add API key in headers
    request.headers['x-api-key'] = apiKey;

    // Add text data as a field
    request.fields['text'] = textData;

    // Add the file as a MultipartFile
    var fileStream = http.ByteStream(file.openRead());
    var length = await file.length();
    var filename = file.path.split('/').last;

    var multipartFile = http.MultipartFile(
      'file', // This is the key the Node.js server expects for the file
      fileStream,
      length,
      filename: filename,
    );

    request.files.add(multipartFile);

    // Send the request
    var response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      logger.d('File and data uploaded successfully');
      var responseData = await http.Response.fromStream(response);
      logger.d('Response: ${responseData.body}');
      return true;
    } else {
      logger.d('Failed to upload. Status code: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    logger.d('Error uploading file: $e');
    return false;
  }
}

Future<String> fetchFileInMemory(String fileId) async {
  String apiUrl = '$localhost:3000/data/$fileId';

  // Send GET request to fetch the file
  var response = await http.get(Uri.parse(apiUrl));
  try {
    // Check if the request was successful
    if (response.statusCode == 200) {
      // File is fetched, you can read the content here
      logger.d('file fetched');
      return utf8.decode(response.bodyBytes);
    } else {
      throw ('Failed to fetch file. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw ('Error fetching file: $e');
  }
}

String encryptData(String plainText, Uint8List password) {
  final iv = getSecureRandom().nextBytes(16);
  var algorithm = PaddedBlockCipher('AES/CBC/PKCS7');
  algorithm.init(
      true,
      PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(password), iv), null));

  final encrypted = algorithm.process(utf8.encode(plainText));
  final ivBase64 = base64Encode(iv);
  final encryptedBase64 = base64Encode(encrypted);

  return '$ivBase64:$encryptedBase64'; // Prepend salt, IV, and encrypted text
}

String decryptData(Uint8List password, String encryptedData) {
  final parts = encryptedData.split(':');
  if (parts.length != 2) {
    throw Exception('Invalid encrypted data format.');
  }

  final iv = base64Decode(parts[0]);
  final encrypted = base64Decode(parts[1]);

  var algorithm = PaddedBlockCipher('AES/CBC/PKCS7');
  algorithm.init(
      false,
      PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(password), iv), null));

  final decrypted = algorithm.process(encrypted);

  return utf8.decode(decrypted);
}

String createMnemonic() {
  return bip39.generateMnemonic();
}

Uint8List getPasswordFromMnemonic(String mnemonic) {
  return bip39
      .mnemonicToSeed(mnemonic)
      .sublist(0, 32); //@dev: AES key length is 32 bytes
}
