import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';

Widget buildOfferCredentialDialog(
    BuildContext context, VerifiableCredential credential, String? toPay) {
  List<Widget> contentData = [];
  contentData.add(Text(
      credential.type
          .firstWhere((element) => element != 'VerifiableCredential'),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
  contentData.add(const SizedBox(
    height: 10,
  ));
  var subject = buildCredSubject(credential.credentialSubject);
  contentData += subject;
  if (toPay != null) {
    contentData.add(
        Text('Für die Austellung wird eine Zahlung von $toPay Satoshi nötig.'));
  }
  contentData.add(const SizedBox(
    height: 10,
  ));
  contentData.add(IssuerInfo(issuer: credential.issuer));

  return AlertDialog(
    title: const Text('Ihnen wird ein Credential angeboten'),
    content: Card(
        child: Column(
      children: contentData,
    )),
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
          child: const Text('Ok'))
    ],
  );
}
