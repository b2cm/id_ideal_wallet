import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

class InsertCard extends StatelessWidget {
  const InsertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            children: [
              Text(
                'Ausweis lesen',
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                  'Bitte halte deinen Ausweis an die NFC-Schnittstelle deines Gerätes. Diese befindet sich meistens an der Rückseite des Gerätes.'),
            ],
          )),
      persistentFooterButtons: [
        ElevatedButton(
            onPressed: () =>
                Provider.of<AusweisProvider>(context, listen: false).cancel(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(45),
            ),
            child: Text('Vorgang Abbrechen')),
      ],
    );
  }
}
