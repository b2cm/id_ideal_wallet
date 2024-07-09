import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class IsoCredentialRequest extends StatefulWidget {
  const IsoCredentialRequest({super.key});

  @override
  IsoCredentialRequestState createState() => IsoCredentialRequestState();
}

class IsoCredentialRequestState extends State<IsoCredentialRequest> {
  @override
  void initState() {
    super.initState();
    Provider.of<MdocProvider>(context, listen: false).startBle();
  }

  @override
  void dispose() {
    Provider.of<MdocProvider>(context, listen: false).stopAdvertising();
    super.dispose();
  }

  Widget getText(MdocProvider mdoc) {
    if (mdoc.transmissionState == BleMdocTransmissionState.uninitialized) {
      return Text('Es wird vorbereitet');
    } else if (mdoc.transmissionState == BleMdocTransmissionState.advertising) {
      return mdoc.qrData.isEmpty
          ? Text('Daten werden erstellt')
          : QrImageView(data: mdoc.qrData);
    } else if (mdoc.transmissionState == BleMdocTransmissionState.connected) {
      return Text('Erfolgreich verbunden. Warte auf Anfrage');
    } else if (mdoc.transmissionState == BleMdocTransmissionState.send) {
      return Text('Daten gesendet');
    } else if (mdoc.transmissionState ==
        BleMdocTransmissionState.disconnected) {
      return Text('Übertragung beendet. Verbindung getrennt');
    } else {
      return Text('Keine Ahnung was grad los ist');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Consumer<MdocProvider>(builder: (context, mdoc, child) {
            return mdoc.bleState == BluetoothLowEnergyState.poweredOn
                ? getText(mdoc)
                : const Text('Bluetooth ist nicht aktiv. Bitte anschalten.');
          }),
        ),
      ),
    );
  }
}
