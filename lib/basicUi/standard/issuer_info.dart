import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/x509.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:x509b/x509.dart' as x509;

class IssuerInfoText extends StatefulWidget {
  final dynamic issuer;
  final bool selfIssued;
  final String? endpoint;

  const IssuerInfoText(
      {super.key,
      required this.issuer,
      this.selfIssued = false,
      this.endpoint});

  @override
  State<StatefulWidget> createState() => IssuerInfoTextState();
}

class IssuerInfoTextState extends State<IssuerInfoText> {
  String issuerName =
      AppLocalizations.of(navigatorKey.currentContext!)!.loadIssuerData;

  @override
  void initState() {
    super.initState();
    //certVerify();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    certVerify();
  }

  void certVerify() async {
    if (widget.selfIssued) {
      issuerName = AppLocalizations.of(context)!.selfIssued;
      setState(() {});
    } else if (widget.issuer is Map) {
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

        issuerName = '$org\n(${AppLocalizations.of(context)!.verified})';

        setState(() {});
      } else if (widget.endpoint != null ||
          widget.issuer.containsKey('oidcEndpoint')) {
        var certInfo = await getCertificateInfoFromUrl(
            widget.endpoint ?? widget.issuer['oidcEndpoint']);
        issuerName = certInfo?.subjectOrganization ??
            certInfo?.subjectCommonName ??
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;

        setState(() {});
      } else if (widget.issuer.containsKey('id') &&
          widget.issuer['id'].startsWith('did:web')) {
        var didUrl = didWebToUri(widget.issuer['id']);
        var certInfo = await getCertificateInfoFromUrl(didUrl.toString());
        issuerName = certInfo?.subjectOrganization ??
            certInfo?.subjectCommonName ??
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;
        if (widget.issuer.containsKey('name')) {
          issuerName = '${widget.issuer['name']} ($issuerName)';
        }

        if (mounted) setState(() {});
      } else if (widget.issuer.containsKey('name')) {
        issuerName =
            '${widget.issuer['name']}\n(${AppLocalizations.of(context)!.notVerified})';
        if (mounted) setState(() {});
      } else {
        issuerName =
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;
      }
    } else if (widget.issuer is VerifiableCredential) {
      issuerName =
          widget.issuer.credentialSubject['companyInformation']['legalName'];
    } else if (widget.endpoint != null) {
      var certInfo = await getCertificateInfoFromUrl(widget.endpoint!);
      issuerName = certInfo?.subjectOrganization ??
          certInfo?.subjectCommonName ??
          AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;

      setState(() {});
    } else {
      if (widget.issuer.startsWith('did:web')) {
        var didUrl = didWebToUri(widget.issuer);
        var certInfo = await getCertificateInfoFromUrl(didUrl.toString());
        issuerName = certInfo?.subjectOrganization ??
            certInfo?.subjectCommonName ??
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;
        setState(() {});
      } else {
        issuerName =
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymousIssuer;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(issuerName,
        style: Theme.of(context).primaryTextTheme.titleMedium);
  }
}

class IssuerInfoIcon extends StatefulWidget {
  final dynamic issuer;
  final bool selfIssued;
  final String? endpoint;

  const IssuerInfoIcon(
      {super.key,
      required this.issuer,
      this.selfIssued = false,
      this.endpoint});

  @override
  State<StatefulWidget> createState() => IssuerInfoIconState();
}

class IssuerInfoIconState extends State<IssuerInfoIcon> {
  IconData marker = Icons.refresh;
  Color iconColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    certVerify();
  }

  void certVerify() async {
    if (widget.selfIssued) {
      marker = Icons.verified_outlined;
      iconColor = Colors.green;
      setState(() {});
    } else if (widget.issuer is Map) {
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
          iconColor = Colors.red;
          marker = Icons.close;
          logger.d('cant verify certificate');
        }
        setState(() {});
      } else if (widget.issuer.containsKey('credentialSubject') &&
          widget.issuer.containsKey('issuer')) {
        marker = Icons.verified_outlined;
        iconColor = Colors.green;
      } else if (widget.issuer.containsKey('id') &&
          widget.issuer['id'].startsWith('did:web')) {
        var didUrl = didWebToUri(widget.issuer['id']);
        var certInfo = await getCertificateInfoFromUrl(didUrl.toString());
        if (certInfo != null && certInfo.valid!) {
          marker = Icons.verified_outlined;
          iconColor = Colors.green;
        }
        if (mounted) setState(() {});
      } else if (widget.endpoint != null ||
          widget.issuer.containsKey('oidcEndpoint')) {
        var certInfo = await getCertificateInfoFromUrl(
            widget.endpoint ?? widget.issuer['oidcEndpoint']);
        if (certInfo != null && certInfo.valid != null && certInfo.valid!) {
          marker = Icons.verified_outlined;
          iconColor = Colors.green;
          setState(() {});
        }
      } else if (widget.issuer.containsKey('name')) {
        marker = Icons.question_mark;
        iconColor = Colors.black54;
        setState(() {});
      }
    } else if (widget.issuer is VerifiableCredential) {
      marker = Icons.verified_outlined;
      iconColor = Colors.green;
      setState(() {});
    } else if (widget.endpoint != null) {
      var certInfo = await getCertificateInfoFromUrl(widget.endpoint!);
      if (certInfo != null && certInfo.valid != null && certInfo.valid!) {
        marker = Icons.verified_outlined;
        iconColor = Colors.green;
        setState(() {});
      }
    } else {
      if (widget.issuer.startsWith('did:web')) {
        var didUrl = didWebToUri(widget.issuer);
        var certInfo = await getCertificateInfoFromUrl(didUrl.toString());
        if (certInfo != null && certInfo.valid!) {
          marker = Icons.verified_outlined;
          iconColor = Colors.green;
        }
        setState(() {});
      } else {
        iconColor = Colors.red;
        marker = Icons.close;
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
