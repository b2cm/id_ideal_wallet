import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:provider/provider.dart';

class AusweisData extends StatelessWidget {
  const AusweisData({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AusweisProvider>(builder: (context, ausweis, child) {
      logger.d(ausweis.statusProgress);
      return Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Ausweisdaten',
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const SizedBox(
                height: 10,
              ),
              if (ausweis.readData != null)
                ...buildCredSubject(ausweis.readData!)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LinearProgressIndicator(
                    value: ausweis.statusProgress,
                    minHeight: 7,
                    semanticsLabel: 'Lese Daten',
                  ),
                )
            ],
          ),
        ),
        persistentFooterButtons: ausweis.selfInfo
            ? [
                FooterButtons(
                    positiveText: 'Als Nachweis speichern',
                    positiveFunction: () {
                      if (ausweis.readData != null) {
                        ausweis.storeAsCredential();
                        Navigator.of(context).pop();
                      }
                    })
              ]
            : [],
      );
    });
  }
}
