import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:x509b/x509.dart' as x509;

class IssuerInfo extends StatefulWidget {
  final dynamic issuer;

  const IssuerInfo({Key? key, required this.issuer}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IssuerInfoState();
}

class IssuerInfoState extends State<IssuerInfo> {
  String marker = '';
  String issuerName = 'Anonymer Aussteller';

  @override
  void initState() {
    super.initState();
    certVerify();
  }

  void certVerify() async {
    if (widget.issuer is Map) {
      if (widget.issuer.containsKey('certificate')) {
        var certIt = x509.parsePem(
            '-----BEGIN CERTIFICATE-----\n${widget.issuer['certificate']}\n-----END CERTIFICATE-----');
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

        issuerName = '$org (verifiziert)';

        try {
          var verified = await verifyIssuerCert(cert);
          if (verified) {
            marker = '\u2713';
          } else {
            marker = '\u2717';
          }
        } catch (e) {
          marker = '\u2717';
        }
        setState(() {});
      } else if (widget.issuer.containsKey('name')) {
        issuerName = '${widget.issuer['name']} (nicht verifiziert)';
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text('$issuerName $marker',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ));
  }
}
