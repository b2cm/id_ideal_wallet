import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:x509b/x509.dart' as x509;

class IssuerInfoText extends StatefulWidget {
  final dynamic issuer;

  const IssuerInfoText({Key? key, required this.issuer}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IssuerInfoTextState();
}

class IssuerInfoTextState extends State<IssuerInfoText> {
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

        setState(() {});
      } else if (widget.issuer.containsKey('name')) {
        issuerName = '${widget.issuer['name']} (nicht verifiziert)';
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(issuerName,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ));
  }
}

class IssuerInfoIcon extends StatefulWidget {
  final dynamic issuer;

  const IssuerInfoIcon({Key? key, required this.issuer}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IssuerInfoIconState();
}

class IssuerInfoIconState extends State<IssuerInfoIcon> {
  IconData marker = Icons.close;
  Color iconColor = Colors.red;

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

        try {
          var verified = await verifyIssuerCert(cert);
          if (verified) {
            marker = Icons.verified_outlined;
            iconColor = Colors.green;
          }
        } catch (e) {
          logger.d('cant verify certificate');
        }
        setState(() {});
      } else if (widget.issuer.containsKey('name')) {
        marker = Icons.question_mark;
        iconColor = Colors.black54;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      marker,
      color: iconColor,
    );
  }
}
