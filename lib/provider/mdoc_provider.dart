import 'dart:async';
import 'dart:convert';

import 'package:base_codecs/base_codecs.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:cbor/cbor.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/iso_credential_request.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:x509b/x509.dart';

class MdocProvider extends ChangeNotifier {
  static const platform = MethodChannel('app.channel.hce');
  static const stream = EventChannel('app.channel.hce/events');

  String? selectedFile;
  Uint8List? handoverSelectMessage;
  SessionEncryptor? encryptor;
  CoseKey? myPrivateKey;
  SessionTranscript? transcript;
  DeviceEngagement? engagement;

  MdocProvider();

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
    var length = apdu.sublist(4, 7);
    logger.d('envelope content length hex: ${hex.encode(length)}');
    var lengthInt = int.parse(hex.encode(length), radix: 16);

    logger.d('envelope content length: $lengthInt');
    var content = apdu.sublist(7, 7 + lengthInt);

    logger.d('envelope content: ${hex.encode(content)}');

    var contentHeader = content.sublist(0, 2);
    logger.d('content header: ${hex.encode(contentHeader)}');

    var contentLength = content.sublist(2, 4);

    var realContent = content.sublist(4);

    var se = SessionEstablishment.fromCbor(realContent);

    var transcriptHolder = SessionTranscript(
        deviceEngagementBytes: engagement!.toDeviceEngagementBytes(),
        keyBytes: se.eReaderKey.toCoseKeyBytes(),
        handover: NFCHandover(handoverSelectMessage: handoverSelectMessage!));

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

    List<VerifiableCredential> toShow = [];
    List<IsoRequestedItem> filterResult = [];

    var isoCreds =
        Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
            .isoMdocCredentials;

    logger.d('isoCreds: $isoCreds');

    for (var cred in isoCreds) {
      var data = IssuerSignedObject.fromCbor(
          base64Decode(cred.plaintextCredential.replaceAll('isoData:', '')));
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
        return;
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
            toShow.add(vc);
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
        credentials: toShow,
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

    if (res) {
      String type = '';
      List<Document> content = [];
      for (var entry in filterResult) {
        var signedData = await generateDeviceSignature(
            entry.revealedData,
            decodedRequest.docRequests.first.itemsRequest.docType,
            transcriptHolder,
            signer: SignatureGenerator.get(entry.privateKey));
        var docToSend = Document(
            docType: entry.docType,
            issuerSigned: entry.issuerSigned,
            deviceSigned: signedData);
        content.add(docToSend);
        type += '${entry.docType},';
      }

      // Generate Response
      var response = DeviceResponse(status: 1, documents: content);

      // Encrypt Response
      var encryptedResponse =
          await encryptor!.encrypt(response.toEncodedCbor());
      var responseToSend =
          SessionData(encryptedData: encryptedResponse).toEncodedCbor();

      var responseLength =
          responseToSend.length.toRadixString(16).padLeft(4, '0');
      logger.d('responseLength: $responseLength');
      sendApdu(
          hex.decode('5382$responseLength') + responseToSend + apduResponseOk);

      Timer(
          const Duration(seconds: 5),
          () => showSuccessMessage(
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .presentationSuccessful,
              type.substring(0, type.length - 1)));
    }
  }

  sendApdu(List<int> data) {
    logger.d('send apdu: ${hex.encode(Uint8List.fromList(data))}');
    try {
      platform.invokeMethod('sendData', Uint8List.fromList(data));
    } on PlatformException catch (e) {
      logger.d('Failed to send apdu to Android: ${e.message}.');
    }
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
