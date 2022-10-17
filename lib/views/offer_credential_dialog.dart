import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:x509b/x509.dart';

Widget buildOfferCredentialDialog(
    BuildContext context, VerifiableCredential credential) {
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
  if (credential.issuer is Map) {
    var issuer = credential.issuer as Map<String, dynamic>;
    if (issuer.containsKey('certificate')) {
      contentData.add(const SizedBox(
        height: 10,
      ));
      contentData.add(const Text('Zertifizierter Issuer',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)));
      contentData.add(Text('Issuer:'));
      var certIt = parsePem(
          '-----BEGIN CERTIFICATE-----\n${issuer['certificate']}\n-----END CERTIFICATE-----');
      var cert = certIt.first as X509Certificate;
      contentData.add(Text(cert.tbsCertificate.subject.toString()));
      contentData.add(Text('verifiziert von:'));
      contentData.add(Text(cert.tbsCertificate.issuer.toString()));
    }
  }
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
