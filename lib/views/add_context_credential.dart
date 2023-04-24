import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class AddContextCredential extends StatefulWidget {
  const AddContextCredential({super.key});

  @override
  AddContextCredentialState createState() => AddContextCredentialState();
}

class AddContextCredentialState extends State<AddContextCredential> {
  List<String> availableCredentials = [
    'Lange Nacht der Wissenschaften - Dresden',
    'Lange Nacht der Wissenschaften - Mittweida',
    //'Lightning Testnetz Wallet'
  ];

  List<int> checkedItems = [];

  void store() async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    for (var i = 0; i < availableCredentials.length; i++) {
      if (i == 0) {
        // LNDW DD
        if (checkedItems.contains(i)) {
          var did = await wallet.newCredentialDid();

          var contextCred = VerifiableCredential(
              context: [credentialsV1Iri, schemaOrgIri],
              type: ['VerifiableCredential', 'ContextCredential'],
              issuer: did,
              id: did,
              credentialSubject: {
                'id': did,
                'name': availableCredentials[i],
                'groupedTypes': ['ChallengeSolvedCredential'],
                'buttons': [
                  {
                    'buttonText': 'Karte anzeigen',
                    'url': 'maps.google.com',
                    'backgroundColor': '#4C4CFF'
                  },
                  {
                    'buttonText': 'Ralley absolvieren ',
                    'url': 'maps.google.com',
                    'backgroundColor': '#00B200'
                  }
                ]
              },
              issuanceDate: DateTime.now());

          var signed =
              await signCredential(wallet.wallet, contextCred.toJson());

          var storageCred = wallet.getCredential(did);

          wallet.storeCredential(signed, storageCred!.hdPath);
          wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
        }
      } else if (i == 1) {
        // LNDW MW
        if (checkedItems.contains(i)) {
          var did = await wallet.newCredentialDid();
          var contextCred = VerifiableCredential(
              context: [credentialsV1Iri, schemaOrgIri],
              type: ['VerifiableCredential', 'ContextCredential'],
              issuer: did,
              id: did,
              credentialSubject: {
                'id': did,
                'name': availableCredentials[i],
                'groupedTypes': ['ChallengeSolvedCredentialMW'],
                'buttons': [
                  {
                    'buttonText': 'Karte anzeigen',
                    'url': 'maps.google.com',
                    'backgroundColor': '#4C4CFF'
                  },
                  {
                    'buttonText': 'Fragen beantworten',
                    'url': 'maps.google.com',
                    'backgroundColor': '#00B200'
                  },
                  {
                    'buttonText': 'Verlosung',
                    'url': 'maps.google.com',
                    'backgroundColor': '#00B200'
                  }
                ]
              },
              issuanceDate: DateTime.now());

          var signed =
              await signCredential(wallet.wallet, contextCred.toJson());

          var storageCred = wallet.getCredential(did);

          wallet.storeCredential(signed, storageCred!.hdPath);
          wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
        }
      }
    }
    Navigator.pop(navigatorKey.currentContext!);
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        footerButtons: [
          TextButton(onPressed: store, child: const Text('Anlegen'))
        ],
        title: 'title',
        scanOnTap: () {},
        child: ListView.builder(
            itemCount: availableCredentials.length,
            itemBuilder: (context, index) {
              return CheckboxListTile(
                value: checkedItems.contains(index),
                title: Text(availableCredentials[index]),
                onChanged: (bool? value) {
                  if (value != null) {
                    if (value) {
                      checkedItems.add(index);
                    } else {
                      checkedItems.remove(index);
                    }
                    setState(() {});
                  }
                },
              );
            }));
  }
}
