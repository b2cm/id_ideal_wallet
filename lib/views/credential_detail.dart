import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_ideal_wallet/views/payment_receipt_pdf.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/show_propose_presentation_code.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:provider/provider.dart';
import 'package:x509b/x509.dart' as x509;

class HistoryEntries extends StatelessWidget {
  const HistoryEntries({Key? key, required this.credDid}) : super(key: key);
  final String credDid;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      var historyEntries = wallet.historyEntriesForCredential(credDid);
      List<Widget> entries = [];

      for (var h in historyEntries) {
        var tile = ListTile(
          leading: Text(
              '${h.timestamp.day}.${h.timestamp.month}.${h.timestamp.year}, ${h.timestamp.hour}:${h.timestamp.minute}'),
          title: Text(h.action == 'issue'
              ? 'Ausgestellt'
              : h.action == 'present'
                  ? 'Vorgezeigt'
                  : 'Vorzeigen fehlgeschlagen'),
        );
        entries.add(tile);
      }
      return ExpansionTile(
        title: const Text('Historie'),
        childrenPadding: const EdgeInsets.all(10),
        children: entries,
      );
    });
  }
}

class CredentialDetailView extends StatefulWidget {
  final VerifiableCredential credential;

  const CredentialDetailView({Key? key, required this.credential})
      : super(key: key);

  @override
  CredentialDetailState createState() => CredentialDetailState();
}

class CredentialDetailState extends State<CredentialDetailView> {
  void _deleteCredential() {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ihnen wird ein Credential angeboten'),
        content: const Card(
            child: Text(
                'Sind Sie sicher, dass sie dieses Credential löschen möchten?\n Dieser Vorgang kann nicht rückgängig gemacht werden.')),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () async {
                wallet.deleteCredential(widget.credential.id ??
                    getHolderDidFromCredential(widget.credential.toJson()));
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const CredentialPage()));
              },
              child: const Text('Löschen'))
        ],
      ),
    );
  }

  List<Widget> _buildOtherData() {
    var otherData = <Widget>[];

    var issDateValue = widget.credential.issuanceDate;
    var issDate = ListTile(
        subtitle: const Text('Ausstelldatum'),
        title: Text(
            '${issDateValue.day.toString().padLeft(2, '0')}. ${issDateValue.month.toString().padLeft(2, '0')}. ${issDateValue.year}'));
    otherData.add(issDate);

    var expDate = widget.credential.expirationDate;
    if (expDate != null) {
      var expDateTile = ListTile(
          subtitle: const Text('Ablaufdatum'),
          title: Text(
            '${expDate.day.toString().padLeft(2, '0')}. ${expDate.month.toString().padLeft(2, '0')}. ${expDate.year}',
            style: expDate.isBefore(DateTime.now())
                ? const TextStyle(color: Colors.red)
                : null,
          ));
      otherData.add(expDateTile);
    }

    var id = widget.credential.id ??
        getHolderDidFromCredential(widget.credential.toJson());
    var statusTile =
        Consumer<WalletProvider>(builder: (context, wallet, child) {
      var status = wallet.revocationState[id];
      String statusText = '';
      switch (status) {
        case 0:
          statusText = 'Gültig';
          break;
        case 1:
          statusText = 'Abgelaufen';
          break;
        case 2:
          statusText = 'inaktiv';
          break;
        case 3:
          statusText = 'zurückgezogen';
          break;
        default:
          statusText = 'Unbekannt';
          break;
      }
      return ListTile(
        subtitle: const Text('Status'),
        title: Text(statusText),
        trailing: InkWell(
          child: const Icon(Icons.refresh),
          onTap: () => wallet.checkValidity(),
        ),
      );
    });
    otherData.add(statusTile);

    return otherData;
  }

  List<Widget> _buildIssuerData() {
    var issuer = <Widget>[];
    if (widget.credential.issuer is Map) {
      var issMap = widget.credential.issuer as Map<String, dynamic>;
      if (issMap.containsKey('certificate')) {
        var certIt = x509.parsePem(
            '-----BEGIN CERTIFICATE-----\n${issMap['certificate']}\n-----END CERTIFICATE-----');
        var cert = certIt.first as x509.X509Certificate;
        var dn = {
          for (var item in cert.tbsCertificate.subject!.names)
            item.keys.first.name: item.values.first
        };
        dn.remove('commonName');
        issuer.addAll(buildCredSubject(dn));
        issuer.add(const SizedBox(
          height: 10,
        ));
        issuer.add(const Text('verifiziert von:'));

        var dnIss = {
          for (var item in cert.tbsCertificate.issuer!.names)
            item.keys.first.name: item.values.first
        };
        issuer.addAll(buildCredSubject(dnIss));
      } else {
        issuer += buildCredSubject(issMap);
      }
    } else if (widget.credential.isSelfIssued()) {
      issuer.add(const Text('Sebtsausgestellt'));
    } else {
      //issuer is String
      issuer.add(Text(widget.credential.issuer));
    }

    return issuer;
  }

  Widget buildReceipt() {
    if (widget.credential.credentialSubject is Map &&
        widget.credential.credentialSubject.containsKey('receiptId')) {
      var receipt = Provider.of<WalletProvider>(context, listen: false)
          .getCredential(widget.credential.credentialSubject['receiptId']);
      if (receipt != null) {
        var receiptVc = VerifiableCredential.fromJson(receipt.w3cCredential);
        return ExpansionTile(
          title: const Text('Rechnung'),
          trailing: InkWell(
            child: const Icon(Icons.picture_as_pdf),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PdfPreviewPage(
                    paymentReceipt: receiptVc,
                    eventName:
                        widget.credential.credentialSubject['event'] ?? ''))),
          ),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: buildCredSubject(receiptVc.credentialSubject),
        );
      }
    }
    return const SizedBox(
      height: 0,
    );
  }

  Widget _buildBody() {
    var personalData = ExpansionTile(
      title: const Text('Persönliche Daten'),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: buildCredSubject(widget.credential.credentialSubject),
    );
    var otherData = ExpansionTile(
      title: const Text('Sonstige Daten'),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: _buildOtherData(),
    );
    var issuerData = ExpansionTile(
      title: const Text('Aussteller'),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: _buildIssuerData(),
    );

    return SingleChildScrollView(
        child: Column(
      children: [
        personalData,
        buildReceipt(),
        issuerData,
        otherData,
        HistoryEntries(
            credDid: getHolderDidFromCredential(widget.credential.toJson()))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: widget.credential.type
          .firstWhere((element) => element != 'VerifiableCredential'),
      scanOnTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const QrScanner())),
      footerButtons: [
        TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => QrRender(credential: widget.credential))),
            child: const Text('zum Vorzeigen anbieten')),
        TextButton(onPressed: _deleteCredential, child: const Text('Löschen'))
      ],
      child: _buildBody(),
    );
  }
}

Card buildCredentialCard(VerifiableCredential credential) {
  List<Widget> content = [
    Text(
        credential.type
            .firstWhere((element) => element != 'VerifiableCredential'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(
      height: 10,
    )
  ];
  content.add(IssuerInfoText(issuer: credential.issuer));
  content.add(const SizedBox(
    height: 10,
  ));
  var additional = buildCredSubject(credential.credentialSubject);
  content += additional;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      ),
    ),
  );
}
