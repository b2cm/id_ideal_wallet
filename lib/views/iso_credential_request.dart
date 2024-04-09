import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:cbor/cbor.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:x509b/x509.dart';

class IsoCredentialRequest extends StatefulWidget {
  const IsoCredentialRequest({super.key});

  @override
  IsoCredentialRequestState createState() => IsoCredentialRequestState();
}

class IsoCredentialRequestState extends State<IsoCredentialRequest>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<BluetoothLowEnergyState> bleState;
  late final ValueNotifier<String> qrData;
  late final ValueNotifier<int> transmissionState;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription characteristicReadSubscription;
  late final StreamSubscription characteristicWrittenSubscription;
  late final StreamSubscription characteristicNotifyStateChangedSubscription;
  late final UUID serviceUuid;
  late final GattService mdocService;
  late final DeviceEngagement engagement;
  late final CoseKey myPrivateKey;
  List<int> readBuffer = [];
  SessionEncryptor? encryptor;
  Central? connectedDevice;

  @override
  void initState() {
    super.initState();

    bleState = ValueNotifier(BluetoothLowEnergyState.unknown);
    transmissionState = ValueNotifier(0);
    qrData = ValueNotifier('');
    serviceUuid = UUID.fromString(const Uuid().v4().toString());
    mdocService = GattService(uuid: serviceUuid, characteristics: [
      mdocPeripheralState,
      mdocPeripheralClient2Server,
      mdocPeripheralServer2Client
    ]);

    setBleState();

    generateDeviceEngagement();

    stateChangedSubscription = PeripheralManager.instance.stateChanged.listen(
      (eventArgs) {
        bleState.value = eventArgs.state;
        logger.d('BluetoothState changed: ${eventArgs.state}');
        if (eventArgs.state == BluetoothLowEnergyState.poweredOn &&
            transmissionState.value != 1) {
          startAdvertising();
        }
      },
    );

    characteristicWrittenSubscription =
        PeripheralManager.instance.characteristicWritten.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final value = eventArgs.value;
        logger.d('${characteristic.uuid} : (${value.length}) $value ');
        // connectedDevice = central;
        if (characteristic.uuid == mdocPeripheralClient2Server.uuid) {
          readBuffer.addAll(value.sublist(1));
          if (value.first == 0) {
            decrypt();
          }
        }
        if (characteristic.uuid == mdocPeripheralState.uuid) {
          if (value.first == 1) {
            logger.d('Start Signal recieved');
          } else if (value.first == 2) {
            logger.d('End Signal received');
            transmissionState.value = 4;
          }
        }
      },
    );

    characteristicNotifyStateChangedSubscription =
        PeripheralManager.instance.characteristicNotifyStateChanged.listen(
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
  }

  decrypt() async {
    var decodedEstablishment = SessionEstablishment.fromCbor(readBuffer);
    var transcriptHolder = SessionTranscript(
        deviceEngagementBytes: engagement.toDeviceEngagementBytes(),
        keyBytes: decodedEstablishment.eReaderKey.toCoseKeyBytes());
    encryptor = SessionEncryptor(
        mdocRole: MdocRole.mdocHolder,
        myPrivateKey: myPrivateKey,
        otherPublicKey: decodedEstablishment.eReaderKey);
    await encryptor!
        .generateKeys(cborEncode(transcriptHolder.toSessionTranscriptBytes()));

    var decryptedRequest =
        await encryptor!.decrypt(decodedEstablishment.encryptedRequest);
    var decodedRequest = DeviceRequest.fromCbor(decryptedRequest);

    logger.d(decodedRequest);

    readBuffer = [];

    // Check Signature
    for (var docRequest in decodedRequest.docRequests) {
      var correctSig =
          await verifyDocRequestSignature(docRequest, transcriptHolder);
      logger.d(correctSig);
      if (!correctSig) {
        logger.d('One false DocRequest');
        throw Exception('Invalid DocRequest');
      }
    }

    var certIt = parsePem(
        '-----BEGIN CERTIFICATE-----\n${base64Encode(decodedRequest.docRequests.first.readerAuthSignature!.unprotected.x509chain!)}\n-----END CERTIFICATE-----');
    var requesterCert = certIt.first as X509Certificate;

    List<VerifiableCredential> toShow = [];
    List<IsoRequestedItem> filterResult = [];

    var isoCreds =
        Provider.of<WalletProvider>(context, listen: false).isoMdocCredentials;

    for (var cred in isoCreds) {
      var data = IssuerSignedObject.fromCbor(
          base64Decode(cred.plaintextCredential.replaceAll('isoData:', '')));
      var m = MobileSecurityObject.fromCbor(data.issuerAuth.payload);
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
            var key = await Provider.of<WalletProvider>(context, listen: false)
                .wallet
                .getPrivateKey(cred.hdPath, KeyType.ed25519);
            filterResult.add(IsoRequestedItem(m.docType, {}, data,
                CoseKey(kty: 1, crv: 6, d: hex.decode(key))));
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
      }

      // Generate Response
      var response = DeviceResponse(status: 1, documents: content);

      // Encrypt Response
      var encryptedResponse =
          await encryptor!.encrypt(response.toEncodedCbor());
      var responseToSend =
          SessionData(encryptedData: encryptedResponse).toEncodedCbor();

      const fragmentSize = 509;
      var start = 0;
      while (start < responseToSend.length) {
        final end = start + fragmentSize;
        final fragmentedValue = end < responseToSend.length
            ? [1] + responseToSend.sublist(start, end)
            : [0] + responseToSend.sublist(start);
        await PeripheralManager.instance.writeCharacteristic(
            mdocPeripheralServer2Client,
            value: Uint8List.fromList(fragmentedValue),
            central: connectedDevice!);
        logger.d('write $start - $end');
        start = end;
      }
    }
    transmissionState.value = 3;
  }

  setBleState() async {
    var s = await PeripheralManager.instance.getState();
    bleState.value = s;
  }

  generateDeviceEngagement() async {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    var mdocDid = await wallet.newConnectionDid(KeyType.p256);
    var deviceEphemeralCosePub = await didToCosePublicKey(mdocDid);
    myPrivateKey = deviceEphemeralCosePub;
    myPrivateKey.d = base64Decode(addPaddingToBase64((await wallet.wallet
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
                  peripheralModeId: serviceUuid.value))
        ]);

    // Encode for Qr-Code
    var encodedEngagement = engagement.toUri();
    logger.d(encodedEngagement);
    qrData.value = encodedEngagement;
    startAdvertising();
  }

  Future<void> startAdvertising() async {
    await PeripheralManager.instance.clearServices();
    await PeripheralManager.instance.addService(mdocService);
    final advertisement = Advertisement(
      name: 'mdoc',
      serviceUUIDs: [serviceUuid],
    );
    await PeripheralManager.instance.startAdvertising(advertisement);
    transmissionState.value = 1; // advertising mode
  }

  Future<void> stopAdvertising() async {
    await PeripheralManager.instance.stopAdvertising();
    transmissionState.value = 2;
  }

  @override
  void dispose() {
    stopAdvertising();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ValueListenableBuilder(
                    valueListenable: bleState,
                    builder: (context, state, child) {
                      return state == BluetoothLowEnergyState.poweredOn
                          ? ValueListenableBuilder(
                              valueListenable: transmissionState,
                              builder: (context, advertising, child) {
                                if (advertising == 0) {
                                  return Text('Es wird vorbereitet');
                                } else if (advertising == 1) {
                                  return ValueListenableBuilder(
                                      valueListenable: qrData,
                                      builder: (context, qrData, child) {
                                        return qrData.isEmpty
                                            ? Text('Daten werden erstellt')
                                            : QrImageView(data: qrData);
                                      });
                                } else if (advertising == 2) {
                                  return Text(
                                      'Erfolgreich verbunden. Warte auf Anfrage');
                                } else if (advertising == 3) {
                                  return Text('Daten gesendet');
                                } else if (advertising == 4) {
                                  return Text(
                                      'Übertragung beendet. Verbindung getrennt');
                                } else {
                                  return Text('Keine Ahnung was grad los ist');
                                }
                              },
                            )
                          : const Text(
                              'Bluetooth ist nicht aktiv. Bitte anschalten.');
                    }))));
  }
}

final GattCharacteristic mdocPeripheralState = GattCharacteristic(
    uuid: UUID.fromString('00000001-A123-48CE-896B-4C76973373E6'),
    properties: [
      GattCharacteristicProperty.notify,
      GattCharacteristicProperty.writeWithoutResponse
    ],
    descriptors: []);

final GattCharacteristic mdocPeripheralClient2Server = GattCharacteristic(
    uuid: UUID.fromString('00000002-A123-48CE-896B-4C76973373E6'),
    properties: [GattCharacteristicProperty.writeWithoutResponse],
    descriptors: []);

final GattCharacteristic mdocPeripheralServer2Client = GattCharacteristic(
    uuid: UUID.fromString('00000003-A123-48CE-896B-4C76973373E6'),
    properties: [
      GattCharacteristicProperty.notify,
    ],
    descriptors: []);

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
