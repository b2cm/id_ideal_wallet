import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/main.dart';

Widget buildOfferCredentialDialog(
    BuildContext context, VerifiableCredential credential) {
  List<Widget> contentData = [];
  contentData.add(Text(credential.type.last,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
  contentData.add(const SizedBox(
    height: 10,
  ));
  var subject = buildCredSubject(credential.credentialSubject);
  contentData += subject;
  return AlertDialog(
    title: const Text('Ihnen wird ein Credential angeboten'),
    content: Card(
        child: Column(
      children: contentData,
    )),
    actions: [
      TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen')),
      TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ok'))
    ],
  );
}
