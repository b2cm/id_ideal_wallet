import 'dart:convert';
import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/ausweis_message.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

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

  AusweisProvider();

  void reset() {
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
    disconnectSdk();
    notifyListeners();
  }

  void startListening() {
    stream.receiveBroadcastStream().listen((data) => handleData(data));
    logger.d('listen data stream');
  }

  void startProgress([String? tcTokenUrl]) {
    connectSdk();
    this.tcTokenUrl = tcTokenUrl;
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
      var signed = await signCredential(wallet.wallet, vc);
      var storedCred = wallet.getCredential(did);
      if (storedCred != null) {
        wallet.storeCredential(signed, storedCred.hdPath);
      } else {
        throw Exception('Das sollte nicht passieren');
      }
      showModalBottomSheet(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10)),
          ),
          context: navigatorKey.currentContext!,
          builder: (context) {
            return ModalDismissWrapper(
              child: PaymentFinished(
                headline: AppLocalizations.of(context)!.credentialReceived,
                success: true,
                amount: const CurrencyDisplay(
                    amount: 'Personalauweis',
                    symbol: '',
                    mainFontSize: 18,
                    centered: true),
              ),
            );
          });
    } catch (e) {
      showErrorMessage('Speichern fehlgeschlagen', e.toString());
    }
    reset();
  }

  void handleData(String data) async {
    logger.d('data received: $data');

    var message = AusweisMessage.fromJson(data);

    if (message is InsertCardMessage) {
      if (screen == AusweisScreen.enterPin ||
          screen == AusweisScreen.enterCan ||
          screen == AusweisScreen.enterPuk) {
      } else {
        screen = AusweisScreen.insertCard;
      }
    } else if (message is EnterPinMessage) {
      screen = AusweisScreen.enterPin;
      pinRetry = message.reader?.cardRetryCounter ?? 3;
      pinEntered = false;
    } else if (message is AccessRightsMessage) {
      requestedAttributes = message.effectiveRights;
      if (requesterCert == null) {
        getCertificate();
      }
    } else if (message is CertificateMessage) {
      requesterCert = message;
    } else if (message is AuthMessage) {
      if (message.major ==
          'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#ok') {
        // successful response
        if (selfInfo) {
          var response = await get(Uri.parse(message.url!),
              headers: {'Accept': 'text/html'});
          logger.d('${response.statusCode} / ${response.body}');
          if (response.statusCode == 200) {
            readData = {};
            var document = XmlDocument.parse(response.body);
            var t = document.findAllElements('td').toList();
            for (int i = 0; i < t.length; i += 2) {
              logger.d('${t[i].innerText} ${t[i + 1].innerText}');
              readData![t[i].innerText] = t[i + 1].innerText;
            }

            screen = AusweisScreen.finish;
            requestedAttributes = [];
            requesterCert = null;
            disconnectSdk();
          }
        } else {
          launchUrl(
            Uri.parse(message.url!),
          );
          reset();
        }
      } else if (message.major ==
          'http://www.bsi.bund.de/ecard/api/1.1/resultmajor#error') {
        if (message.minor ==
            'http://www.bsi.bund.de/ecard/api/1.1/resultminor/sal#cancellationByUser') {
          reset();
        } else {
          errorDescription =
              message.description ?? 'Es ist ein Fehler aufgetreten';
          errorMessage =
              message.message ?? 'Es liegt keine Beschreibung des Fehlers vor';
          screen = AusweisScreen.error;
        }
      }
    } else if (message is StatusMessage) {
      if (pinEntered) {
        screen = AusweisScreen.finish;
      } else {
        screen = AusweisScreen.main;
      }
      statusProgress =
          message.progress == null ? null : message.progress! / 100;
      logger.d(statusProgress);
    } else if (message is ReaderMessage) {
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
    } else if (message is DisconnectMessage) {
      logger.d('Successfully disconnected');
    } else if (message is EnterCanMessage) {
      screen = AusweisScreen.enterCan;
    } else if (message is EnterPukMessage) {
      screen = AusweisScreen.enterPuk;
    }

    notifyListeners();
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
}
