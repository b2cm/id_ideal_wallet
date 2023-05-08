import 'dart:async';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';
import 'package:x509b/x509.dart' as x509;

class PdfPreviewPage extends StatelessWidget {
  final VerifiableCredential paymentReceipt;
  final String eventName;

  const PdfPreviewPage(
      {Key? key, required this.paymentReceipt, required this.eventName})
      : super(key: key);

  FutureOr<Uint8List> _makePdf(PdfPageFormat format) async {
    String issuerName = '';
    String issuerStreet = '';
    String issuerPostalCode = '';
    String issuerLocation = '';
    if (paymentReceipt.issuer is Map) {
      if (paymentReceipt.issuer.containsKey('certificate')) {
        var certIt = x509.parsePem(
            '-----BEGIN CERTIFICATE-----\n${paymentReceipt.issuer['certificate']}\n-----END CERTIFICATE-----');
        var cert = certIt.first as x509.X509Certificate;

        var orgMap = cert.tbsCertificate.subject?.names.firstWhere(
            (element) =>
                element.containsKey(const x509.ObjectIdentifier([2, 5, 4, 10])),
            orElse: () => {
                  const x509.ObjectIdentifier([2, 5, 4, 10]): ''
                });
        String org = orgMap![const x509.ObjectIdentifier([2, 5, 4, 10])];
        issuerName = org;
      } else if (paymentReceipt.issuer.containsKey['name']) {
        issuerName = paymentReceipt.issuer['name'];
      }

      issuerStreet = paymentReceipt.issuer['streetAddress'] ??
          paymentReceipt.issuer['address']?['streetAddress'] ??
          '';
      issuerPostalCode = paymentReceipt.issuer['postalCode'] ??
          paymentReceipt.issuer['address']?['postalCode'] ??
          '';
      issuerLocation = paymentReceipt.issuer['addressLocality'] ??
          paymentReceipt.issuer['address']?['addressLocality'] ??
          '';
    }

    String subjectLocation =
        paymentReceipt.credentialSubject['address']?['addressLocality'] ?? '';
    String subjectPostalCode =
        paymentReceipt.credentialSubject['address']?['postalCode'] ?? '';
    String subjectStreet =
        paymentReceipt.credentialSubject['address']?['streetAddress'] ?? '';

    var dataBase =
        await rootBundle.load('assets/fonts/Outfit/Outfit-Medium.ttf');
    var dataBold = await rootBundle.load('assets/fonts/Outfit/Outfit-Bold.ttf');
    final file = pdf.Document();
    file.addPage(pdf.Page(
        theme: pdf.ThemeData.withFont(
            base: pdf.Font.ttf(dataBase), bold: pdf.Font.ttf(dataBold)),
        build: (context) {
          return pdf.Column(
              crossAxisAlignment: pdf.CrossAxisAlignment.start,
              mainAxisAlignment: pdf.MainAxisAlignment.start,
              children: [
                // issuer
                pdf.Text(issuerName),
                pdf.Text(issuerStreet),
                pdf.Text('$issuerPostalCode $issuerLocation'),
                pdf.SizedBox(height: 20),
                // subject
                pdf.Text(
                    '${paymentReceipt.credentialSubject['givenName'] ?? ''} ${paymentReceipt.credentialSubject['familyName'] ?? ''}'),
                pdf.Text(subjectStreet),
                pdf.Text('$subjectPostalCode $subjectLocation'),
                pdf.SizedBox(height: 20),
                // Date
                pdf.Row(
                    mainAxisAlignment: pdf.MainAxisAlignment.end,
                    children: [
                      pdf.Text(
                          '${paymentReceipt.issuanceDate.day.toString().padLeft(2, '0')}.${paymentReceipt.issuanceDate.month.toString().padLeft(2, '0')}.${paymentReceipt.issuanceDate.year}'),
                    ]), // content
                pdf.Header(
                    child: pdf.Text(
                        AppLocalizations.of(navigatorKey.currentContext!)!
                            .invoice,
                        style: pdf.TextStyle(
                            fontSize: 16, fontWeight: pdf.FontWeight.bold))),
                pdf.Text(
                    '${AppLocalizations.of(navigatorKey.currentContext!)!.invoiceNumber}: ${paymentReceipt.credentialSubject['receiptId']}'),
                pdf.SizedBox(height: 15),
                pdf.Table(
                    border: const pdf.TableBorder(
                        horizontalInside: pdf.BorderSide()),
                    children: [
                      pdf.TableRow(children: [
                        pdf.Text('Pos.'),
                        pdf.Text('Name'.padRight(60, ' ')),
                        pdf.Text('Preis'),
                        pdf.Text('MwSt.')
                      ]),
                      pdf.TableRow(children: [
                        pdf.Text('1'),
                        pdf.Text(eventName),
                        pdf.Text(
                            paymentReceipt.credentialSubject['priceWithMwst']),
                        pdf.Text(paymentReceipt.credentialSubject['mwst'])
                      ])
                    ]),
                pdf.Divider(),
                pdf.Row(
                    mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                    children: [
                      pdf.Text(
                          '${AppLocalizations.of(navigatorKey.currentContext!)!.total}:'),
                      pdf.Text(
                          paymentReceipt.credentialSubject['priceWithMwst'])
                    ])
              ]);
        }));

    return file.save();
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      scanOnTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const QrScanner())),
      title:
          '${AppLocalizations.of(context)!.invoice} - ${AppLocalizations.of(context)!.preview}',
      child: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: AppLocalizations.of(context)!.invoice,
        build: (context) => _makePdf(PdfPageFormat.a4),
      ),
    );
  }
}
