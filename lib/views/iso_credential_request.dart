import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:cbor_test/cbor_test.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class IsoCredentialRequest extends StatefulWidget {
  const IsoCredentialRequest({super.key});

  @override
  IsoCredentialRequestState createState() => IsoCredentialRequestState();
}

class IsoCredentialRequestState extends State<IsoCredentialRequest>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<String> qrData;
  late final ValueNotifier<bool> advertising;
  late final ValueNotifier<List<Log>> logs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription characteristicReadSubscription;
  late final StreamSubscription characteristicWrittenSubscription;
  late final StreamSubscription characteristicNotifyStateChangedSubscription;
  late final UUID serviceUuid;
  late final GattService mdocService;
  List<int> readBuffer = [];

  @override
  void initState() {
    super.initState();

    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    advertising = ValueNotifier(false);
    logs = ValueNotifier([]);
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
        state.value = eventArgs.state;
        logger.d('BluetoothState changed: ${eventArgs.state}');
        if (eventArgs.state == BluetoothLowEnergyState.poweredOn &&
            advertising.value == false) {
          startAdvertising();
        }
      },
    );

    characteristicReadSubscription =
        PeripheralManager.instance.characteristicRead.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final value = eventArgs.value;
        final log = Log(
          LogType.read,
          value,
          'central: ${central.uuid}; characteristic: ${characteristic.uuid}',
        );
        logs.value = [
          ...logs.value,
          log,
        ];
      },
    );

    characteristicWrittenSubscription =
        PeripheralManager.instance.characteristicWritten.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final value = eventArgs.value;
        logger.d('${characteristic.uuid} : (${value.length}) $value ');
        if (characteristic.uuid == mdocPeripheralClient2Server.uuid) {
          readBuffer.addAll(value.sublist(3));
          if (value.first == 0) {
            decrypt();
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
      },
    );
  }

  decrypt() async {}

  setBleState() async {
    var s = await PeripheralManager.instance.getState();
    state.value = s;
  }

  generateDeviceEngagement() async {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    var mdocDid = await wallet.newConnectionDid(KeyType.p256);
    var deviceEphemeralCosePub = await didToCosePublicKey(mdocDid);
    var deviceEphemeralCosePriv = deviceEphemeralCosePub;
    deviceEphemeralCosePriv.d = base64Decode(addPaddingToBase64((await wallet
        .wallet
        .getPrivateKeyForConnectionDidAsJwk(mdocDid))!['d']));
    var bleEngagement = DeviceEngagement(
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
    var encodedEngagement =
        removePaddingFromBase64(base64Encode(bleEngagement.toCbor()));
    logger.d('mdoc:$encodedEngagement');
    qrData.value = 'mdoc:$encodedEngagement';
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
    advertising.value = true;
  }

  Future<void> stopAdvertising() async {
    await PeripheralManager.instance.stopAdvertising();
    advertising.value = false;
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
                    valueListenable: state,
                    builder: (context, state, child) {
                      return state == BluetoothLowEnergyState.poweredOn
                          ? ValueListenableBuilder(
                              valueListenable: advertising,
                              builder: (context, advertising, child) {
                                return advertising
                                    ? ValueListenableBuilder(
                                        valueListenable: qrData,
                                        builder: (context, qrData, child) {
                                          return qrData.isEmpty
                                              ? Text('Daten werden erstellt')
                                              : QrImageView(data: qrData);
                                        })
                                    : Text('Es wird vorbereitet');
                              },
                            )
                          : const Text(
                              'Bluetooth ist nicht aktiv. Bitte anschalten.');
                    }))));
  }
}

class Log {
  final DateTime time;
  final LogType type;
  final Uint8List value;
  final String? detail;

  Log(
    this.type,
    this.value, [
    this.detail,
  ]) : time = DateTime.now();

  @override
  String toString() {
    final type = this.type.toString().split('.').last;
    final formatter = DateFormat.Hms();
    final time = formatter.format(this.time);
    final message = value.toString();
    if (detail == null) {
      return '[$type]$time: $message';
    } else {
      return '[$type]$time: $message /* $detail */';
    }
  }
}

enum LogType {
  read,
  write,
  notify,
  error,
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
