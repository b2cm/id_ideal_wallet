import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:x509b/x509.dart' as x509;

Widget buildIssuerInfo(dynamic issuer) {
  if (issuer is Map) {
    if (issuer.containsKey('certificate')) {
      var certIt = x509.parsePem(
          '-----BEGIN CERTIFICATE-----\n${issuer['certificate']}\n-----END CERTIFICATE-----');
      var cert = certIt.first as x509.X509Certificate;

      var commonNameMap = cert.tbsCertificate.subject?.names.firstWhere(
          (element) =>
              element.containsKey(const x509.ObjectIdentifier([2, 5, 4, 3])),
          orElse: () => {
                const x509.ObjectIdentifier([2, 5, 4, 3]): ''
              });
      String commonName =
          commonNameMap![const x509.ObjectIdentifier([2, 5, 4, 3])];
      var orgMap = cert.tbsCertificate.subject?.names.firstWhere(
          (element) =>
              element.containsKey(const x509.ObjectIdentifier([2, 5, 4, 10])),
          orElse: () => {
                const x509.ObjectIdentifier([2, 5, 4, 10]): ''
              });
      String org = orgMap![const x509.ObjectIdentifier([2, 5, 4, 10])];
      if (org.isEmpty) {
        org = commonName;
      }

      return Text.rich(TextSpan(children: [
        TextSpan(text: 'Aussteller: $org (verifiziert)'),
        WidgetSpan(
            child: FutureBuilder<bool>(
          future: verifyIssuerCert(cert),
          builder: (context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data!) {
                return const Icon(Icons.verified_rounded);
              } else {
                return const Icon(Icons.close);
              }
            } else if (snapshot.hasError) {
              print(snapshot.error);
              return const Icon(Icons.close);
            } else {
              return const Icon(Icons.query_builder_rounded);
            }
          },
        ))
      ]));
    } else {
      return Text('Aussteller: ${issuer['name']} (nicht verifizierbar)');
    }
  } else {
    return const Text('Anonymer Aussteller');
  }
}
