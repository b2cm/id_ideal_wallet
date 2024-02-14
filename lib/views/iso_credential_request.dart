import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class IsoCredentialRequest extends StatefulWidget {
  const IsoCredentialRequest({super.key});

  @override
  IsoCredentialRequestState createState() => IsoCredentialRequestState();
}

class IsoCredentialRequestState extends State<IsoCredentialRequest>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<BluetoothLowEnergyState> state;
  late final ValueNotifier<bool> advertising;
  late final ValueNotifier<List<Log>> logs;
  late final StreamSubscription stateChangedSubscription;
  late final StreamSubscription characteristicReadSubscription;
  late final StreamSubscription characteristicWrittenSubscription;
  late final StreamSubscription characteristicNotifyStateChangedSubscription;
  late final UUID serviceUuid;
  late final GattService mdocService;

  @override
  void initState() {
    super.initState();

    state = ValueNotifier(BluetoothLowEnergyState.unknown);
    advertising = ValueNotifier(false);
    logs = ValueNotifier([]);
    serviceUuid = UUID.fromString(const Uuid().v4().toString());
    mdocService = GattService(uuid: serviceUuid, characteristics: [
      mdocPeripheralState,
      mdocPeripheralClient2Server,
      mdocPeripheralServer2Client
    ]);

    stateChangedSubscription = PeripheralManager.instance.stateChanged.listen(
      (eventArgs) {
        state.value = eventArgs.state;
        logger.d('BluetoothState changed: ${eventArgs.state}');
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
        final log = Log(
          LogType.write,
          value,
          'central: ${central.uuid}; characteristic: ${characteristic.uuid}',
        );
        logs.value = [
          ...logs.value,
          log,
        ];
      },
    );

    characteristicNotifyStateChangedSubscription =
        PeripheralManager.instance.characteristicNotifyStateChanged.listen(
      (eventArgs) async {
        final central = eventArgs.central;
        final characteristic = eventArgs.characteristic;
        final state = eventArgs.state;
        final log = Log(
          LogType.notify,
          Uint8List.fromList([]),
          'central: ${central.uuid}; characteristic: ${characteristic.uuid}; state: $state',
        );
        logs.value = [
          ...logs.value,
          log,
        ];
        // Write someting to the central when notify started.
        if (state) {
          final elements = List.generate(2000, (i) => i % 256);
          final value = Uint8List.fromList(elements);
          await PeripheralManager.instance.writeCharacteristic(
            characteristic,
            value: value,
            central: central,
          );
        }
      },
    );
  }

  Future<void> startAdvertising() async {
    await PeripheralManager.instance.clearServices();
    await PeripheralManager.instance.addService(mdocService);
    final advertisement = Advertisement(
      name: 'mdoc',
      manufacturerSpecificData: ManufacturerSpecificData(
        id: 0x2e19,
        data: Uint8List.fromList([0x01, 0x02, 0x03]),
      ),
    );
    await PeripheralManager.instance.startAdvertising(advertisement);
    advertising.value = true;
  }

  Future<void> stopAdvertising() async {
    await PeripheralManager.instance.stopAdvertising();
    advertising.value = false;
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
                                return TextButton(
                                  onPressed: () async {
                                    if (advertising) {
                                      await stopAdvertising();
                                    } else {
                                      await startAdvertising();
                                    }
                                  },
                                  child: Text(
                                    advertising ? 'END' : 'BEGIN',
                                  ),
                                );
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
