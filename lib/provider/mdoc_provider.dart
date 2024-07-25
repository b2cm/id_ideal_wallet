import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:base_codecs/base_codecs.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:cbor/cbor.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:x509b/x509.dart';

enum BleMdocTransmissionState {
  uninitialized,
  advertising,
  connected,
  disconnected,
  send
}

class MdocProvider extends ChangeNotifier {
  static const platform = MethodChannel('app.channel.hce');
  static const stream = EventChannel('app.channel.hce/events');

  // NFC
  String? selectedFile;
  Uint8List? handoverSelectMessage;
  SessionEncryptor? encryptor;
  CoseKey? myPrivateKey;
  SessionTranscript? transcript;
  DeviceEngagement? engagement;
  List<int> nfcMessage = [];
  int leMax = 0;
  int bytesSend = 0;
  List<int>? responseToSend;
  String? typeToShow;

  // BLE
  BluetoothLowEnergyState bleState = BluetoothLowEnergyState.unknown;
  String qrData = '';
  BleMdocTransmissionState transmissionState =
      BleMdocTransmissionState.uninitialized;
  StreamSubscription? stateChangedSubscription;
  StreamSubscription? characteristicReadSubscription;
  StreamSubscription? characteristicWrittenSubscription;
  StreamSubscription? characteristicNotifyStateChangedSubscription;
  UUID? serviceUuid;
  GATTService? mdocService;
  PeripheralManager? peripheralManager;
  List<int> readBuffer = [];
  Central? connectedDevice;

  MdocProvider();

  // BLE
  void startBle() {
    peripheralManager = PeripheralManager();
    serviceUuid = UUID.fromString(const Uuid().v4().toString());
    mdocService = GATTService(
        uuid: serviceUuid!,
        characteristics: [
          mdocPeripheralState,
          mdocPeripheralClient2Server,
          mdocPeripheralServer2Client
        ],
        isPrimary: true,
        includedServices: []);

    setBleState();

    generateDeviceEngagement();

    stateChangedSubscription = peripheralManager!.stateChanged.listen(
      (eventArgs) async {
        bleState = eventArgs.state;
        logger.d('BluetoothState changed: ${eventArgs.state}');
        if (Platform.isAndroid &&
            eventArgs.state == BluetoothLowEnergyState.unauthorized) {
          await peripheralManager!.authorize();
          startAdvertising();
        }
        if (eventArgs.state == BluetoothLowEnergyState.poweredOn &&
            transmissionState != BleMdocTransmissionState.advertising) {
          startAdvertising();
        }
        notifyListeners();
      },
    );

    characteristicWrittenSubscription =
        peripheralManager!.characteristicWriteRequested.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final request = eventArgs.request;
        final offset = request.offset;
        final value = request.value;
        logger.d('${characteristic.uuid} : (${value.length}) $value ');
        // connectedDevice = central;
        if (characteristic.uuid == mdocPeripheralClient2Server.uuid) {
          readBuffer.addAll(value.sublist(1));
          if (value.first == 0) {
            sendResponse();
          }
        }
        if (characteristic.uuid == mdocPeripheralState.uuid) {
          if (value.first == 1) {
            logger.d('Start Signal recieved');
          } else if (value.first == 2) {
            logger.d('End Signal received');
            transmissionState = BleMdocTransmissionState.disconnected;
          }
        }
      },
    );

    characteristicNotifyStateChangedSubscription =
        peripheralManager!.characteristicNotifyStateChanged.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final state = eventArgs.state;
        logger.d('${characteristic.uuid} : $state');
        if (state) {
          connectedDevice = central;
          stopAdvertising();
        }
      },
    );

    notifyListeners();
  }

  setBleState() async {
    var s = peripheralManager?.state;
    logger.d(s);
    bleState = s ?? BluetoothLowEnergyState.unknown;
  }

  generateDeviceEngagement() async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var mdocDid = await wallet.newConnectionDid(KeyType.p256);
    var deviceEphemeralCosePub = await didToCosePublicKey(mdocDid);
    myPrivateKey = deviceEphemeralCosePub;
    myPrivateKey!.d = base64Decode(addPaddingToBase64((await wallet.wallet
        .getPrivateKeyForConnectionDidAsJwk(mdocDid))!['d']));
    engagement = DeviceEngagement(
        security: Security(
            cipherSuiteIdentifier: 1,
            deviceKeyBytes: deviceEphemeralCosePub.toCoseKeyBytes().bytes),
        deviceRetrievalMethods: [
          DeviceRetrievalMethod(
              type: 2,
              options: BLEOptions(
                  supportPeripheralServerMode: true,
                  supportCentralClientMode: false,
                  peripheralModeId: serviceUuid!.value))
        ]);

    // Encode for Qr-Code
    var encodedEngagement = engagement!.toUri();
    logger.d(encodedEngagement);
    qrData = encodedEngagement;

    if (bleState == BluetoothLowEnergyState.poweredOn) startAdvertising();
  }

  Future<void> startAdvertising() async {
    await peripheralManager?.removeAllServices();
    await peripheralManager?.addService(mdocService!);
    final advertisement = Advertisement(
      //name: 'mdoc',
      serviceUUIDs: [serviceUuid!],
    );
    await peripheralManager?.startAdvertising(advertisement);
    transmissionState =
        BleMdocTransmissionState.advertising; // advertising mode
  }

  Future<void> stopAdvertising() async {
    await peripheralManager?.stopAdvertising();
    transmissionState = BleMdocTransmissionState.connected;
    notifyListeners();
  }

  Future<void> sendResponse() async {
    List<int>? responseToSend;
    String? type;

    (responseToSend, type) = await handleMdocRequest(readBuffer);

    if (responseToSend != null) {
      var fragmentSize =
          await peripheralManager!.getMaximumNotifyLength(connectedDevice!) - 3;
      var start = 0;
      while (start < responseToSend.length) {
        final end = start + fragmentSize;
        final fragmentedValue = end < responseToSend.length
            ? [1] + responseToSend.sublist(start, end)
            : [0] + responseToSend.sublist(start);
        await peripheralManager!.notifyCharacteristic(
            connectedDevice!, mdocPeripheralServer2Client,
            value: Uint8List.fromList(fragmentedValue));
        logger.d('write $start - $end');
        start = end;
      }

      transmissionState = BleMdocTransmissionState.send;
    }
    notifyListeners();
  }

  //NFC
  void startListening() {
    stream.receiveBroadcastStream().listen((apdu) => handleApdu(apdu));
    logger.d('listen hce stream');
  }

  void handleApdu(Uint8List apdu) {
    logger.d('APDU received: ${hex.encode(apdu)}');

    if (apdu.length < 5) {
      logger.d('apdu to short');
      sendApdu(apduResponseFileNotFound);
      return;
    }

    var instruction = apdu[1];
    var p1 = apdu[2];
    var p2 = apdu[3];

    if (instruction == 164) {
      // Select command
      var length = apdu[4];
      if (p1 == 4) {
        // select aid
        var aid = apdu.sublist(5, 5 + length);
        handleSelectAid(aid);
      } else if (p1 == 0) {
        // select file
        handleSelectFile(apdu.sublist(5, 5 + length));
      }
    } else if (instruction == 176) {
      // read binary
      handleReadBinary(apdu[4]);
    } else if (instruction == 195) {
      // envelope
      handleEnvelope(apdu);
    } else if (instruction == 192) {
      handleGetResponse(apdu);
    } else {
      sendApdu(apduResponseInstructionNotSupported);
    }
  }

  handleSelectAid(Uint8List aid) {
    var aidHex = hex.encode(aid);
    if (aidHex == aidType4Tag || aidHex == aidMdoc) {
      sendApdu(apduResponseOk);
    } else {
      sendApdu(apduResponseFileNotFound);
    }
  }

  handleSelectFile(Uint8List fileId) {
    selectedFile = hex.encode(fileId);
    sendApdu(apduResponseOk);
  }

  handleReadBinary(int expectedLength) {
    logger.d('handle binary, selected file: $selectedFile');
    if (selectedFile == 'E103') {
      // capability container
      if (expectedLength != 15) {
        logger.d('unexpected length');
        sendApdu(apduResponseFileNotFound);
        return;
      }
      sendApdu(ndefCapability + apduResponseOk);
    } else if (selectedFile == 'E104') {
      if (expectedLength == 2) {
        bytesSend = 0;
        responseToSend = [];
        nfcMessage = [];
        // generate stuff and send length
        var nfcForumRecord = NdefRecordData(
            type: utf8.encode('Hs'),
            payload: hex.decode('15D10209616301013001046D646F63'),
            basicType: NdefBasicType.wellKnown);

        myPrivateKey = CoseKey.generate(CoseCurve.p256);
        engagement = DeviceEngagement(
            security: Security(
                deviceKeyBytes:
                    myPrivateKey!.toPublicKey().toCoseKeyBytes().bytes));
        var mdocRecord = NdefRecordData(
            type: utf8.encode('iso.org:18013:deviceengagement'),
            payload: Uint8List.fromList(engagement!.toEncodedCbor()),
            basicType: NdefBasicType.external,
            id: utf8.encode('mdoc'));

        var bleUuid = UUID.fromString(const Uuid().v4().toString());
        var bleOobHex = '021c00${hex.encode(Uint8List.fromList([
              bleUuid.value.length + 1
            ]))}07${hex.encode(Uint8List.fromList(bleUuid.value.reversed.toList()))}';
        var bleRecord = NdefRecordData(
            type: utf8.encode('application/vnd.bluetooth.le.oob'),
            payload: hex.decode(bleOobHex),
            basicType: NdefBasicType.media,
            id: hex.decode('30'));

        var nfcRecord = NdefRecordData(
            type: utf8.encode('iso.org:18013:nfc'),
            id: utf8.encode('nfc'),
            payload: hex.decode('010301ffff0302ffff'),
            basicType: NdefBasicType.external);

        handoverSelectMessage =
            buildNdefMessage([nfcForumRecord, mdocRecord, nfcRecord]);

        var l = handoverSelectMessage!.length;
        sendApdu(hex.decode(l.toRadixString(16).padLeft(4, '0')).toList() +
            apduResponseOk);
      } else if (expectedLength == handoverSelectMessage?.length) {
        sendApdu(handoverSelectMessage!.toList() + apduResponseOk);
      } else {
        sendApdu(apduResponseFileNotFound);
      }
    } else {
      sendApdu(apduResponseFileNotFound);
    }
  }

  handleEnvelope(Uint8List apdu) async {
    var cla = apdu[0];
    bool extendedLength = false;
    if (cla == 16) {
      extendedLength = true;
    } else if (cla != 0) {
      logger.d('unknown cla');
      sendApdu(apduResponseFileNotFound);
      return;
    }
    int length = apdu[4];
    int offset = 5;
    if (length == 0) {
      offset = 7;
      var lengthHex = hex.encode(apdu.sublist(5, 7));
      logger.d('envelope content length hex: $lengthHex');
      length = int.parse(lengthHex, radix: 16);
      logger.d('envelope content length: $length');
    }

    var content = apdu.sublist(offset, offset + length);
    logger.d('envelope content: ${hex.encode(content)}');

    var le = apdu.sublist(offset + length);
    logger.d('le: $le');
    nfcMessage += content;
    if (extendedLength) {
      if (le.first == 0) {
        sendApdu(apduResponseOk);
      }
    } else {
      leMax = int.parse(hex.encode(le), radix: 16);
      logger.d(leMax);
      if (offset == 5) {
        logger.d('short message; maybe end of communication');
        return;
      }
      handleNfcRequest();
    }
  }

  handleGetResponse(Uint8List apdu) {
    int le = int.parse(hex.encode(apdu.sublist(apdu.length - 2)), radix: 16);
    leMax = le;
    sendNfcResponse();
  }

  handleNfcRequest() async {
    var contentHeader = nfcMessage.sublist(0, 2);
    logger
        .d('content header: ${hex.encode(Uint8List.fromList(contentHeader))}');

    var contentLength = nfcMessage.sublist(2, 4);

    var realContent = nfcMessage.sublist(4);

    List<int>? responseToSend;

    String? type = '';

    (responseToSend, type) = await handleMdocRequest(realContent);

    nfcMessage = [];

    if (responseToSend != null) {
      var header = getEnvelopeHeader(responseToSend.length);
      this.responseToSend = hex.decode(header) + responseToSend;
      typeToShow = type;
      sendNfcResponse();
    }
  }

  sendNfcResponse() {
    logger.d('responseLength: ${responseToSend!.length - bytesSend}');

    if (leMax >= responseToSend!.length - bytesSend) {
      // everything fits
      nfcMessage = [];
      sendApdu(responseToSend!.sublist(bytesSend) + apduResponseOk);

      Timer(const Duration(seconds: 5), () {
        bytesSend = 0;
        responseToSend = [];
        showSuccessMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .presentationSuccessful,
            typeToShow?.substring(0, typeToShow!.length - 1) ?? '');
      });
    } else {
      bytesSend += leMax;
      var content = responseToSend!.sublist(bytesSend - leMax, leMax);
      logger.d('content length = ${content.length}');
      int remaining = responseToSend!.length - bytesSend;
      sendApdu(content + [97, remaining > 255 ? 0 : remaining]);
    }
  }

  String getEnvelopeHeader(int length) {
    String beginHex = '53';
    if (length < 128) {
      beginHex += length.toRadixString(16).padLeft(2, '0');
    } else if (length < 256) {
      beginHex += '81${length.toRadixString(16).padLeft(2, '0')}';
    } else if (length < 65536) {
      beginHex += '82${length.toRadixString(16).padLeft(4, '0')}';
    } else if (length < 16777216) {
      beginHex += '83${length.toRadixString(16).padLeft(6, '0')}';
    } else {
      logger.d('content too long');
      throw Exception('Content too long');
    }

    return beginHex;
  }

  sendApdu(List<int> data) {
    logger.d('send apdu: ${hex.encode(Uint8List.fromList(data))}');
    try {
      platform.invokeMethod('sendData', Uint8List.fromList(data));
    } on PlatformException catch (e) {
      logger.d('Failed to send apdu to Android: ${e.message}.');
    }
  }

  Future<(List<int>?, String?)> handleMdocRequest(List<int> request) async {
    var se = SessionEstablishment.fromCbor(request);

    var transcriptHolder = SessionTranscript(
        deviceEngagementBytes: engagement!.toDeviceEngagementBytes(),
        keyBytes: se.eReaderKey.toCoseKeyBytes(),
        handover: handoverSelectMessage == null
            ? null
            : NFCHandover(handoverSelectMessage: handoverSelectMessage!));

    encryptor = SessionEncryptor(
        mdocRole: MdocRole.mdocHolder,
        myPrivateKey: myPrivateKey!,
        otherPublicKey: se.eReaderKey);

    await encryptor!
        .generateKeys(cborEncode(transcriptHolder.toSessionTranscriptBytes()));

    var decryptedRequest = await encryptor!.decrypt(se.encryptedRequest);
    var decodedRequest = DeviceRequest.fromCbor(decryptedRequest);

    logger.d(decodedRequest);

    // Check Signature
    for (var docRequest in decodedRequest.docRequests) {
      if (docRequest.readerAuthSignature != null) {
        var correctSig =
            await verifyDocRequestSignature(docRequest, transcriptHolder);
        logger.d(correctSig);
        if (!correctSig!) {
          logger.d('One false DocRequest');
          throw Exception('Invalid DocRequest');
        }
      }
    }

    var certIt = parsePem(
        '-----BEGIN CERTIFICATE-----\n${base64Encode(decodedRequest.docRequests.first.readerAuthSignature!.unprotected.x509chain!)}\n-----END CERTIFICATE-----');
    var requesterCert = certIt.first as X509Certificate;

    List<IssuerSignedObject> toShow = [];
    List<IsoRequestedItem> filterResult = [];

    var isoCreds =
        Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
            .isoMdocCredentials;

    logger.d('isoCreds: $isoCreds');

    for (var cred in isoCreds) {
      var data = IssuerSignedObject.fromCbor(
          base64Decode(cred.plaintextCredential.replaceAll('$isoPrefix:', '')));
      var m = MobileSecurityObject.fromCbor(data.issuerAuth.payload);
      var coseKey = m.deviceKeyInfo.deviceKey;
      KeyType keyType;
      if (coseKey.crv == CoseCurve.ed25519) {
        keyType = KeyType.ed25519;
      } else if (coseKey.crv == CoseCurve.p521) {
        keyType = KeyType.p521;
      } else if (coseKey.crv == CoseCurve.p384) {
        keyType = KeyType.p384;
      } else if (coseKey.crv == CoseCurve.p256) {
        keyType = KeyType.p256;
      } else {
        showErrorMessage('Unbekannter KeyType', 'Das sollte nicht passieren');
        logger.d(coseKey);
        return (null, null);
      }
      for (var docRequest in decodedRequest.docRequests) {
        logger.d(
            '${docRequest.itemsRequest.docType} ==? ${m.docType}: ${docRequest.itemsRequest.docType == m.docType}');
        if (docRequest.itemsRequest.docType == m.docType) {
          Map<String, List<IssuerSignedItem>> revealedData = getDataToReveal(
              decodedRequest.docRequests.first.itemsRequest, data);
          logger.d(revealedData);
          if (revealedData.isNotEmpty) {
            var contentToShow = revealedData.values.fold(<String, dynamic>{},
                (previousValueA, element) {
              previousValueA.addAll(
                  element.fold(<String, dynamic>{}, (previousValue, element) {
                previousValue[element.dataElementIdentifier] =
                    element.dataElementValue;
                return previousValue;
              }));
              return previousValueA;
            });

            data.items = revealedData;
            var vc = VerifiableCredential.fromJson(cred.w3cCredential);
            vc.credentialSubject = contentToShow;
            toShow.add(data);
            var key = await Provider.of<WalletProvider>(
                    navigatorKey.currentContext!,
                    listen: false)
                .wallet
                .getPrivateKey(cred.hdPath, keyType);
            filterResult.add(IsoRequestedItem(
                m.docType,
                {},
                data,
                CoseKey(
                    kty: coseKey.kty, crv: coseKey.crv, d: hex.decode(key))));
          }
        }
      }
    }

    var asFilter = FilterResult(
        credentials: [],
        isoMdocCredentials: toShow,
        matchingDescriptorIds: [],
        presentationDefinitionId: '');

    var res = await Navigator.of(navigatorKey.currentContext!).push(
      MaterialPageRoute(
        builder: (context) => PresentationRequestDialog(
          definition: PresentationDefinition(inputDescriptors: []),
          definitionHash: '',
          otherEndpoint: '',
          receiverDid: '',
          myDid: '',
          results: [asFilter],
          isIso: true,
          requesterCert: requesterCert,
        ),
      ),
    );

    if (res != null) {
      String type = '';
      List<Document> content = [];
      logger.d(res.runtimeType);
      res as List<FilterResult>;
      for (var entry in res) {
        for (var doc in entry.isoMdocCredentials ?? <IssuerSignedObject>[]) {
          var mso = MobileSecurityObject.fromCbor(doc.issuerAuth.payload);
          var did = coseKeyToDid(mso.deviceKeyInfo.deviceKey);

          var private = await Provider.of<WalletProvider>(
                  navigatorKey.currentContext!,
                  listen: false)
              .getPrivateKeyForCredentialDid(did);
          if (private == null) {
            showErrorMessage('Kein privater schlüssel');
            return (null, null);
          }
          var privateKey = await didToCosePublicKey(did);
          privateKey.d = hexDecode(private);

          var ds = await generateDeviceSignature(
              {}, mso.docType, transcriptHolder,
              signer: SignatureGenerator.get(privateKey));

          var docToSend = Document(
              docType: mso.docType, issuerSigned: doc, deviceSigned: ds);
          content.add(docToSend);
          type += '${mso.docType},';
        }
      }
      // for (var entry in filterResult) {
      //   var signedData = await generateDeviceSignature(
      //       entry.revealedData,
      //       decodedRequest.docRequests.first.itemsRequest.docType,
      //       transcriptHolder,
      //       signer: SignatureGenerator.get(entry.privateKey));
      //   var docToSend = Document(
      //       docType: entry.docType,
      //       issuerSigned: entry.issuerSigned,
      //       deviceSigned: signedData);
      //   content.add(docToSend);
      //   type += '${entry.docType},';
      // }

      // Generate Response
      var response = DeviceResponse(status: 1, documents: content);

      // Encrypt Response
      var encryptedResponse =
          await encryptor!.encrypt(response.toEncodedCbor());
      return (
        SessionData(encryptedData: encryptedResponse).toEncodedCbor(),
        type
      );
    }
    return (null, null);
  }
}

const apduResponseOk = [144, 0];
const apduResponseFileNotFound = [106, 130];
const apduResponseInstructionNotSupported = [109, 0];

const aidType4Tag = 'D2760000850101';
const aidMdoc = 'A0000002480400';

const ndefCapability = [
  0,
  15,
  // size
  32,
  // version
  127,
  255,
  // max response data length
  127,
  255,
  // max command data length
  4,
  6,
  // ndef file control
  225,
  4,
  // ndef file id
  127,
  255,
  // max ndef data length
  0,
  // allow read
  255
  // disallow write for static handover (use 0 = allow for negotiated handover)
];

class NdefRecordData {
  Uint8List? id;
  Uint8List type, payload;
  NdefBasicType basicType;

  NdefRecordData(
      {required this.type,
      required this.payload,
      required this.basicType,
      this.id});
}

enum NdefBasicType {
  wellKnown,
  media,
  absoluteUri,
  external,
  unknown,
  unchanged
}

Uint8List buildNdefMessage(List<NdefRecordData> data) {
  List<int> message = [];
  int count = 0;
  for (var r in data) {
    var messageBegin = count == 0 ? '1' : '0';
    var messageEnd = count == data.length - 1 ? '1' : '0';
    var chunk = '0';
    var short = '1';
    var idPresent = r.id == null ? '0' : '1';
    var tnf = '000';
    if (r.basicType == NdefBasicType.wellKnown) {
      tnf = '001';
    } else if (r.basicType == NdefBasicType.media) {
      tnf = '010';
    } else if (r.basicType == NdefBasicType.absoluteUri) {
      tnf = '011';
    } else if (r.basicType == NdefBasicType.external) {
      tnf = '100';
    } else if (r.basicType == NdefBasicType.unknown) {
      tnf = '101';
    } else if (r.basicType == NdefBasicType.unchanged) {
      tnf = '110';
    }

    var headerBin = '$messageBegin$messageEnd$chunk$short$idPresent$tnf';

    message += [int.parse(headerBin, radix: 2)];
    message += [r.type.length];
    message += hex.decode(r.payload.length.toRadixString(16)).toList();
    if (r.id != null) {
      message += [r.id!.length];
    }
    message += r.type;
    if (r.id != null) {
      message += r.id!;
    }
    message += r.payload;

    count++;
  }

  return Uint8List.fromList(message);
}

final GATTCharacteristic mdocPeripheralState = GATTCharacteristic.mutable(
    uuid: UUID.fromString('00000001-A123-48CE-896B-4C76973373E6'),
    properties: [
      GATTCharacteristicProperty.notify,
      GATTCharacteristicProperty.writeWithoutResponse
    ],
    descriptors: [],
    permissions: [
      GATTCharacteristicPermission.read,
      GATTCharacteristicPermission.write,
    ]);

final GATTCharacteristic mdocPeripheralClient2Server =
    GATTCharacteristic.mutable(
        uuid: UUID.fromString('00000002-A123-48CE-896B-4C76973373E6'),
        properties: [
      GATTCharacteristicProperty.writeWithoutResponse
    ],
        descriptors: [],
        permissions: [
      GATTCharacteristicPermission.read,
      GATTCharacteristicPermission.write,
    ]);

final GATTCharacteristic mdocPeripheralServer2Client =
    GATTCharacteristic.mutable(
        uuid: UUID.fromString('00000003-A123-48CE-896B-4C76973373E6'),
        properties: [
      GATTCharacteristicProperty.notify,
    ],
        descriptors: [],
        permissions: [
      GATTCharacteristicPermission.read,
      GATTCharacteristicPermission.write,
    ]);

class IsoRequestedItem {
  CoseKey privateKey;
  Map<String, Map<String, dynamic>> revealedData;
  IssuerSignedObject issuerSigned;
  String docType;

  IsoRequestedItem(
      this.docType, this.revealedData, this.issuerSigned, this.privateKey);
}

Future<CoseKey> didToCosePublicKey(String did) async {
  var didDoc = await resolveDidDocument(did);
  didDoc = didDoc.resolveKeyIds().convertAllKeysToJwk();

  var keyAsJwk = didDoc.verificationMethod!.first.publicKeyJwk;

  print(keyAsJwk);

  CoseKey cose;

  if (did.startsWith('did:key:z6Mk')) {
    cose = CoseKey(
        kty: CoseKeyType.octetKeyPair,
        crv: CoseCurve.ed25519,
        x: base64Decode(addPaddingToBase64(keyAsJwk!['x']))); // x : pub key
  } else {
    int crv;
    if (did.startsWith('did:key:zDn')) {
      crv = CoseCurve.p256;
    } else if (did.startsWith('did:key:z82')) {
      crv = CoseCurve.p384;
    } else {
      crv = CoseCurve.p521;
    }

    cose = CoseKey(
        kty: CoseKeyType.ec2,
        crv: crv,
        x: base64Decode(addPaddingToBase64(keyAsJwk!['x'])), // x : pub key
        y: base64Decode(addPaddingToBase64(keyAsJwk['y'])) // y: pub key
        );
  }

  return cose;
}
