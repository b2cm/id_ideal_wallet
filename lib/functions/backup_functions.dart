import 'dart:convert';
import 'dart:io';

import 'package:base_codecs/base_codecs.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/encryption_provider.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/server_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:path_provider/path_provider.dart';
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
  Uint8List password = EncryptionService.getPasswordFromMnemonic(memonic);

  var encodedBoxes = jsonEncode(data);

  // Encrypt boxes
  final encryptedData = EncryptionService.encryptData(encodedBoxes, password);

  // Save the file locally first
  File file =
      await saveFileLocally(hexEncode(sha256.process(password)), encryptedData);
  logger.d('local file saved');

  String apiUrl =
      '$localhost/data'; // Replace with your server URL      // Replace with your API key
  String textData = hexEncode(sha256.process(password));

  return await sendStringAndFile(apiUrl, apiKey, textData, file);
}

Future<Map<String, Map<String, dynamic>>?> loadAndDecryptBackup(
    String mnemonic) async {
  Uint8List password = EncryptionService.getPasswordFromMnemonic(mnemonic);

  try {
    var encryptedData =
        await fetchFileInMemory(hexEncode(sha256.process(password)));

    // Decrypt the data using the password
    String encodedBoxes =
        EncryptionService.decryptData(password, encryptedData);
    logger.d('decrypted');

    var walletData = (jsonDecode(encodedBoxes) as Map).map((k, v) => MapEntry(
        k as String, (v as Map).map((k1, v1) => MapEntry(k1 as String, v1))));
    return walletData;
  } catch (e) {
    // if we catch here we did not get a 200
    logger.d(e);
    return null;
  }
}

// Function to apply backup
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
