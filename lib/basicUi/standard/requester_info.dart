import 'package:dart_ssi/x509.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/root_certificates.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:x509b/x509.dart' as x509;

class RequesterInfo extends StatefulWidget {
  final String requesterUrl;
  final String followingText;
  final x509.X509Certificate? requesterCert;

  const RequesterInfo(
      {super.key,
      required this.requesterUrl,
      required this.followingText,
      this.requesterCert});

  @override
  State<StatefulWidget> createState() => RequesterInfoState();
}

class RequesterInfoState extends State<RequesterInfo> {
  String info =
      AppLocalizations.of(navigatorKey.currentContext!)!.loadIssuerData;
  bool isLoading = true;
  bool isVerified = false;

  @override
  void initState() {
    super.initState();
    getInfo();
  }

  void getInfo() async {
    try {
      if (widget.requesterCert != null) {
        var commonNameMap = widget.requesterCert!.tbsCertificate.subject?.names
            .firstWhere(
                (element) => element
                    .containsKey(const x509.ObjectIdentifier([2, 5, 4, 3])),
                orElse: () => {
                      const x509.ObjectIdentifier([2, 5, 4, 3]): ''
                    });
        String commonName =
            commonNameMap![const x509.ObjectIdentifier([2, 5, 4, 3])];

        var orgMap = widget.requesterCert!.tbsCertificate.subject?.names
            .firstWhere(
                (element) => element
                    .containsKey(const x509.ObjectIdentifier([2, 5, 4, 10])),
                orElse: () => {
                      const x509.ObjectIdentifier([2, 5, 4, 10]): ''
                    });
        String org = orgMap![const x509.ObjectIdentifier([2, 5, 4, 10])];

        if (org.isEmpty) {
          org = commonName;
        }
        info = org;
        isVerified =
            await x509.verifyCertificate(widget.requesterCert, rootCerts.first);
      } else {
        var certInfo = await getCertificateInfoFromUrl(widget.requesterUrl);
        info = certInfo?.subjectOrganization ??
            certInfo?.subjectCommonName ??
            AppLocalizations.of(navigatorKey.currentContext!)!.anonymous;
        if (certInfo != null) {
          isVerified = true;
        }
      }
      setState(() {});
    } catch (e) {
      AppLocalizations.of(navigatorKey.currentContext!)!.anonymous;
      logger.d('Problem bei Zertifikatsabfrage: $e');
    }
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).primaryTextTheme.titleMedium,
          children: [
            TextSpan(
              text: info,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            WidgetSpan(
              child: Container(
                padding: const EdgeInsets.only(
                  left: 1,
                  bottom: 5,
                ),
                child: Icon(
                  isLoading
                      ? Icons.refresh
                      : isVerified
                          ? Icons.check_circle
                          : Icons.close,
                  size: 14,
                  color: isLoading
                      ? Colors.grey
                      : isVerified
                          ? Colors.greenAccent.shade700
                          : Colors.redAccent.shade700,
                ),
              ),
            ),
            TextSpan(
                text: widget.followingText,
                style: Theme.of(context).primaryTextTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
