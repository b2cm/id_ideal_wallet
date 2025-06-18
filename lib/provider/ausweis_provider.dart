import 'dart:convert';
import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/ausweis_message.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:sd_jwt/sd_jwt.dart' as sd_jwt;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

enum AusweisScreen {
  enterPin,
  main,
  insertCard,
  start,
  finish,
  enterCan,
  enterPuk,
  error
}

typedef CustomTypeHandler = void Function(dynamic data);

class AusweisProvider extends ChangeNotifier {
  static const method = MethodChannel('app.channel.method');
  static const stream = EventChannel('app.channel.event');

  AusweisScreen screen = AusweisScreen.start;
  List<String> requestedAttributes = [];
  CertificateMessage? requesterCert;
  double? statusProgress;
  bool start = false;
  bool pinEntered = false;
  Map<String, dynamic>? readData;
  int pinRetry = 3;
  String errorDescription = '';
  String errorMessage = '';
  String? tcTokenUrl;
  bool selfInfo = true;
  bool connected = false;
  bool pause = false;
  bool pidFlow = false;

  late final Map<Type, CustomTypeHandler> typeHandlers;

  AusweisProvider() {
    typeHandlers = {
      InsertCardMessage: handleInsertCardMessage,
      PauseMessage: handlePauseMessage,
      EnterPinMessage: handleEnterPinMessage,
      AccessRightsMessage: handleAccessRightsMessage,
      CertificateMessage: handleCertificateMessage,
      AuthMessage: handleAuthMessage,
      StatusMessage: handleStatusMessage,
      ReaderMessage: handleReaderMessage,
      DisconnectMessage: handleDisconnectMessage,
      EnterCanMessage: handleEnterCanMessage,
      EnterPukMessage: handleEnterPukMessage
    };
  }

  void reset([bool notify = true]) {
    screen = AusweisScreen.start;
    requestedAttributes = [];
    requesterCert = null;
    start = false;
    pinEntered = false;
    readData = null;
    statusProgress = null;
    pinRetry = 3;
    errorDescription = '';
    errorMessage = '';
    selfInfo = true;
    pause = false;
    pidFlow = false;
    disconnectSdk();
    if (notify) notifyListeners();
  }

  void startListening() {
    stream.receiveBroadcastStream().listen((data) => handleData(data));
    logger.d('listen data stream');
  }

  void startProgress([String? tcTokenUrl, bool pidFlow = false]) {
    connectSdk();
    this.tcTokenUrl = tcTokenUrl;
    this.pidFlow = pidFlow;
    screen = AusweisScreen.main;
    start = true;
    notifyListeners();
  }

  void storeAsCredential() async {
    try {
      var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
          listen: false);
      var did = await wallet.newCredentialDid();
      readData!['id'] = did;
      var vc = VerifiableCredential(
          id: did,
          context: [credentialsV1Iri, schemaOrgIri],
          type: ['VerifiableCredential', 'Personalausweis'],
          credentialSubject: readData,
          issuer: did,
          issuanceDate: DateTime.now());
      var (signer, proofType) = await getCredentialSigningStuff(wallet, did);
      await vc.sign(signer, proofType);
      //var storedCred = wallet.getCredential(did);
      //if (storedCred != null) {
      wallet.storeCredential(vc, did);
      // } else {
      //   throw Exception('Das sollte nicht passieren');
      // }

      showSuccessMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.credentialReceived,
          'Personalausweis');
    } catch (e) {
      showErrorMessage('Speichern fehlgeschlagen', e.toString());
    }
    reset();
  }

  Future<void> requestSignedCredential() async {
    var nonceRes = await get(Uri.parse('http://localhost:8080/nonce'));
    if (nonceRes.statusCode == 200) {
      var nonce = jsonDecode(nonceRes.body)['nonce'];

      var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
          listen: false);
      var keyId = await wallet.newCredentialDid(KeyType.p256, KeyStore.system);
      logger.d(keyId);
      var info = await wallet.wallet
          .getKeyInformation(wallet.getOsKeyStoreIdForDid(keyId)!);
      var jwt = sd_jwt.Jwt(
          additionalClaims: {'nonce': nonce},
          header: sd_jwt.JoseHeader(
              x509certificateChain: (info['x5c'] as List)
                  .map((e) => base64Decode(e as String))
                  .toList()));
      logger.d(jwt);
      var jws = await jwt.sign(
          header: sd_jwt.JwsJoseHeader(
              algorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime,
              x509certificateChain: (info['x5c'] as List)
                  .map((e) => base64Decode(e as String))
                  .toList()),
          signer: WalletCryptoProviderForSdJwt(
              wallet.wallet, wallet.getOsKeyStoreIdForDid(keyId)!),
          signingAlgorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime);
      logger.d(jws.header);
      var attRes = await post(Uri.parse('http://localhost:8080/ausweis'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(
              {'jwt': jws.toCompactSerialization(), 'data': readData}));
      logger.d(attRes.body);
      var credential = attRes.body;
      var parsed = sd_jwt.SdJws.fromCompactSerialization(credential);
      var sd = sd_jwt.SdJwt.fromSdJws(parsed);
      logger.d(parsed.jsonContent());

      var iss = parsed.jsonContent()['payload']['iss'];
      var issMetaUrl = '$iss/.well-known/jwt-vc-issuer';

      logger.d(issMetaUrl);

      var metaRes = await get(Uri.parse(issMetaUrl));
      if (metaRes.statusCode != 200) {
        logger.d('Kein Public Key, Verifikation nicht möglich');
        showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
        );
        return;
      }

      var data = jsonDecode(metaRes.body);
      var jwks = data['jwks'];
      logger.d(jwks);
      List keys = jwks['keys'];
      logger.d(keys);
      Map k = keys.first;
      var jwk = sd_jwt.Jwk.fromJson(
          k.map((key, value) => MapEntry(key as String, value)));
      var verified = await sd.verify(parsed,
          sd_jwt.PointyCastleCryptoProvider(jwk.key as sd_jwt.EcPublicKey));

      logger.d(verified);

      var cnf = sd.confirmation!.toJson();
      logger.d(cnf['jwk']);
      var multibase = jwkToMultiBase(cnf['jwk']);
      logger.d('did:key:$multibase');
      var restoredDid = 'did:key:$multibase';

      var claims = sd.additionalClaims ?? {};
      var type = claims.remove('vct');
      claims['id'] = restoredDid;

      var vc = VerifiableCredential(
          id: restoredDid,
          context: [credentialsV1Iri, schemaOrgIri],
          type: ['VerifiableCredential', type],
          issuer: {
            'id': iss,
            if (jwk.x509CertificateChain != null)
              'certificate': jwk.x509CertificateChain!.first
          },
          credentialSubject: claims,
          issuanceDate: sd.issuedAt ?? DateTime.now(),
          expirationDate: sd.expirationTime);

      wallet.storeCredential(vc, restoredDid,
          isoMdlData: '$sdPrefix:$credential');
      wallet.storeExchangeHistoryEntry(
          restoredDid, DateTime.now(), 'issue', iss);
      reset();
    } else {
      reset();
    }
  }

  void handleData(String data) async {
    logger.d('data received: $data');

    var message = AusweisMessage.fromJson(data);

    CustomTypeHandler? handler = typeHandlers[message.runtimeType];
    if (handler != null) {
      handler(message);
    } else {
      logger.d("No handler for ${data.runtimeType}");
    }
  }

  void connectSdk() {
    try {
      method.invokeMethod('connectSdk');
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
      connected = false;
      return;
    }
    connected = true;
  }

  void disconnectSdk() {
    try {
      method.invokeMethod('disconnectSdk');
    } on PlatformException catch (e) {
      logger.d('Failed to disconnect from sdk: ${e.message}.');
      return;
    }
    connected = false;
  }

  void getInfo() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'GET_INFO'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void getStatus() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'GET_STATUS'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void checkApiLevel() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'GET_API_LEVEL'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void setApiLevel(int newLevel) {
    try {
      method.invokeMethod('sendCommand',
          jsonEncode({'cmd': 'SET_API_LEVEL', 'level': newLevel}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void getReader(String readerName) {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({'cmd': 'GET_READER', 'name': readerName}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void getReaderList() {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({'cmd': 'GET_READER_LIST'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void runAuth(
      {required String tcTokenUrl,
      bool developerMode = false,
      bool handleInterrupt = false,
      bool status = true,
      String? sessionStartedMessage,
      String? sessionFailedMessage,
      String? sessionSucceedMessage,
      String? sessionInProgressMessage}) {
    Map<String, dynamic> cmd = {
      'cmd': 'RUN_AUTH',
      "tcTokenURL": tcTokenUrl,
      "developerMode": developerMode,
      "handleInterrupt": handleInterrupt,
      'status': status
    };
    if (Platform.isIOS) {
      Map<String, String> messages = {};
      if (sessionStartedMessage != null) {
        messages['sessionStarted'] = sessionStartedMessage;
      }
      if (sessionFailedMessage != null) {
        messages['sessionFailed'] = sessionFailedMessage;
      }
      if (sessionSucceedMessage != null) {
        messages['sessionSucceeded'] = sessionSucceedMessage;
      }
      if (sessionInProgressMessage != null) {
        messages['sessionInProgress'] = sessionInProgressMessage;
      }
      cmd['messages'] = messages;
    }
    try {
      method.invokeMethod('sendCommand', jsonEncode(cmd));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void runChangePin(
      {bool handleInterrupt = false,
      bool status = true,
      String? sessionStartedMessage,
      String? sessionFailedMessage,
      String? sessionSucceedMessage,
      String? sessionInProgressMessage}) {
    Map<String, dynamic> cmd = {
      'cmd': 'RUN_CHANGE_PIN',
      "handleInterrupt": handleInterrupt,
      'status': status
    };
    if (Platform.isIOS) {
      Map<String, String> messages = {};
      if (sessionStartedMessage != null) {
        messages['sessionStarted'] = sessionStartedMessage;
      }
      if (sessionFailedMessage != null) {
        messages['sessionFailed'] = sessionFailedMessage;
      }
      if (sessionSucceedMessage != null) {
        messages['sessionSucceeded'] = sessionSucceedMessage;
      }
      if (sessionInProgressMessage != null) {
        messages['sessionInProgress'] = sessionInProgressMessage;
      }
      cmd['messages'] = messages;
    }
    try {
      method.invokeMethod('sendCommand', jsonEncode(cmd));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void runDemoAuth() {
    runAuth(
        // tcTokenUrl:
        //     'https://test.governikus-eid.de/AusweisAuskunft/WebServiceRequesterServlet',
        tcTokenUrl:
            'https://www.autentapp.de/AusweisAuskunft/WebServiceRequesterServlet',
        developerMode: false);
  }

  void getAccessRights() {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({'cmd': 'GET_ACCESS_RIGHTS'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void setAccessRights(List<String> accessRights) {
    try {
      method.invokeMethod('sendCommand',
          jsonEncode({'cmd': 'SET_ACCESS_RIGHTS', 'chat': accessRights}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void setCard(
      {required String readerName,
      List<Map<String, dynamic>>? files,
      List<Map<String, dynamic>>? keys}) {
    Map<String, dynamic> cmd = {'cmd': 'SET_CARD', 'name': readerName};

    if (files != null || keys != null) {
      Map<String, dynamic> sim = {};
      if (files != null) {
        sim['files'] = files;
      }
      if (keys != null) {
        sim['keys'] = keys;
      }
      cmd['simulator'] = sim;
    }
    try {
      method.invokeMethod('sendCommand', jsonEncode(cmd));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void getCertificate() {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({'cmd': 'GET_CERTIFICATE'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void cancel() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'CANCEL'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void accept() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'ACCEPT'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void interrupt() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'INTERRUPT'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void sendContinue() {
    try {
      method.invokeMethod('sendCommand', jsonEncode({'cmd': 'CONTINUE'}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void setPin(String pin) {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({"cmd": "SET_PIN", "value": pin}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
    pinEntered = true;
    screen = AusweisScreen.finish;
  }

  void setNewPin(String pin) {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({"cmd": "SET_NEW_PIN", "value": pin}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
  }

  void setCan(String can) {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({"cmd": "SET_CAN", "value": can}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
    screen = AusweisScreen.finish;
  }

  void setPuk(String puk) {
    try {
      method.invokeMethod(
          'sendCommand', jsonEncode({"cmd": "SET_PUK", "value": puk}));
    } on PlatformException catch (e) {
      logger.d('Failed to connect to sdk: ${e.message}.');
    }
    screen = AusweisScreen.finish;
  }

  void handleInsertCardMessage(dynamic message) {
    if (message is InsertCardMessage) {
      if (screen != AusweisScreen.enterPin &&
          screen != AusweisScreen.enterCan &&
          screen != AusweisScreen.enterPuk) {
        screen = AusweisScreen.insertCard;
      }
    } else {
      logger.d("Incorrect type for handleInsertCardMessage");
    }
    notifyListeners();
  }

  void handlePauseMessage(dynamic message) {
    if (message is PauseMessage) {
      screen = AusweisScreen.insertCard;
      pause = true;
      logger.d('set pause: $pause');
    } else {
      logger.d("Incorrect type for handlePauseMessage");
    }
    notifyListeners();
  }

  void handleEnterPinMessage(dynamic message) {
    if (message is EnterPinMessage) {
      screen = AusweisScreen.enterPin;
      pinRetry = message.reader?.cardRetryCounter ?? 3;
      pinEntered = false;
    } else {
      logger.d("Incorrect type for handleEnterPinMessage");
    }
    notifyListeners();
  }

  void handleAccessRightsMessage(dynamic message) {
    if (message is AccessRightsMessage) {
      requestedAttributes = message.effectiveRights;
      if (requesterCert == null) {
        getCertificate();
      }
    } else {
      logger.d("Incorrect type for handleAccessRightsMessage");
    }
    notifyListeners();
  }

  void handleCertificateMessage(dynamic message) {
    if (message is CertificateMessage) {
      requesterCert = message;
    } else {
      logger.d("Incorrect type for handleCertificateMessage");
    }
    notifyListeners();
  }

  void handleAuthMessage(dynamic message) async {
    if (message is AuthMessage) {
      if (message.major ==
          'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok') {
        // successful response
        if (selfInfo) {
          var response = await get(Uri.parse(message.url!),
              headers: {'Accept': 'application/json'});
          logger.d('${response.statusCode} / ${response.body}');

          if (response.statusCode == 200) {
            readData = jsonDecode(response.body);

            screen = AusweisScreen.finish;
            requestedAttributes = [];
            requesterCert = null;
            disconnectSdk();
          } else {
            errorDescription = 'Es ist ein Fehler aufgetreten';
            errorMessage = 'Daten können nicht abgerufen werden';
            screen = AusweisScreen.error;
            requestedAttributes = [];
            requesterCert = null;
            disconnectSdk();
          }
        } else if (pidFlow) {
          //var redirect = await get(Uri.parse(message.url!));
          // logger.d(redirect.statusCode);
          // logger.d(redirect.headers);
          http.Request req = http.Request("Get", Uri.parse(message.url!))
            ..followRedirects = false;
          http.Client baseClient = http.Client();
          http.StreamedResponse response = await baseClient.send(req);
          var redirectUri = response.headers['location']!;
          logger.d(response.statusCode);
          logger.d(response.headers);
          if (response.statusCode == 302) {
            handleRedirect(redirectUri, response.headers['dpop-nonce']);
          } else {
            Navigator.pop(navigatorKey.currentContext!);
          }
          reset(false);
        } else {
          launchUrl(Uri.parse(message.url!),
              mode: LaunchMode.externalApplication);
          logger.d('launched');
          Navigator.pop(navigatorKey.currentContext!);
          logger.d('page changed?');
          reset(false);
        }
      } else if (message.major ==
              'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error' &&
          message.minor ==
              'http://www.bsi.bund.de/ecard/api/1.1/resultminor/sal#cancellationByUser') {
        if (message.reason == 'User_Cancelled') {
          reset();
        } else {
          errorDescription =
              message.description ?? 'Es ist ein Fehler aufgetreten';
          errorMessage =
              message.message ?? 'Es liegt keine Beschreibung des Fehlers vor';
          screen = AusweisScreen.error;
        }
      }
    } else {
      logger.d("Incorrect type for handleAuthMessage");
    }
    notifyListeners();
  }

  void handleStatusMessage(dynamic message) {
    if (message is StatusMessage) {
      if (pinEntered) {
        screen = AusweisScreen.finish;
      } else {
        screen = AusweisScreen.main;
      }
      statusProgress =
          message.progress == null ? null : message.progress! / 100;
      logger.d(statusProgress);
    } else {
      logger.d("Incorrect type for handleStatusMessage");
    }
    notifyListeners();
  }

  void handleReaderMessage(dynamic message) {
    if (message is ReaderMessage) {
      if (start) {
        if (tcTokenUrl == null) {
          runDemoAuth();
        } else {
          runAuth(tcTokenUrl: tcTokenUrl!);
          selfInfo = false;
        }
        start = false;
      }

      if (message.cardRetryCounter != null) {
        pinRetry = 3;
      }

      logger.d(pause);

      if (pause) {
        if (message.cardRetryCounter != null &&
            message.cardDeactivated != null &&
            message.cardInoperative != null) {
          sendContinue();
          if (pinEntered) {
            screen = AusweisScreen.finish;
          } else {
            screen = AusweisScreen.main;
          }
          pause = false;
        }
      }
    } else {
      logger.d("Incorrect type for handleReaderMessage");
    }
    notifyListeners();
  }

  void handleDisconnectMessage(dynamic message) {
    if (message is DisconnectMessage) {
      logger.d('Successfully disconnected');
    } else {
      logger.d("Incorrect type for handleDisconnectMessage");
    }
    notifyListeners();
  }

  void handleEnterCanMessage(dynamic message) {
    if (message is EnterCanMessage) {
      screen = AusweisScreen.enterCan;
    } else {
      logger.d("Incorrect type for handleEnterCanMessage");
    }
    notifyListeners();
  }

  void handleEnterPukMessage(dynamic message) {
    if (message is EnterPukMessage) {
      screen = AusweisScreen.enterPuk;
    } else {
      logger.d("Incorrect type for handleEnterPukMessage");
    }
    notifyListeners();
  }
}
