import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';

Widget buildOfferCredentialDialog(
    BuildContext context, List<LdProofVcDetail> credentials, String? toPay) {
  List<Widget> buildCred() {
    List<Widget> contentData = [];
    for (var d in credentials) {
      var credential = d.credential;
      contentData.add(Text(
          credential.type
              .firstWhere((element) => element != 'VerifiableCredential'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
      contentData.add(const SizedBox(
        height: 10,
      ));
      var subject = buildCredSubject(credential.credentialSubject);
      contentData += subject;

      contentData.add(const SizedBox(
        height: 10,
      ));
      contentData.add(IssuerInfo(issuer: credential.issuer));
    }

    if (toPay != null) {
      contentData.add(Text(
          'Für die Ausstellung wird eine Zahlung von $toPay Satoshi nötig.'));
    }
    return contentData;
  }

  return AlertDialog(
    title: const Text('Ihnen wird ein Credential angeboten'),
    content: SingleChildScrollView(
        child: Card(
            child: Column(
      children: buildCred(),
    ))),
    actions: [
      TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Abbrechen')),
      TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: toPay == null ? const Text('Ok') : const Text('Bezahlen'))
    ],
  );
}
