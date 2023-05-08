import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/basicUi/standard/top_up.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_ideal_wallet/views/payment_receipt_pdf.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/show_propose_presentation_code.dart';
import 'package:provider/provider.dart';
import 'package:x509b/x509.dart' as x509;

class HistoryEntries extends StatelessWidget {
  const HistoryEntries({Key? key, required this.credential}) : super(key: key);
  final VerifiableCredential credential;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      var credId =
          credential.id ?? getHolderDidFromCredential(credential.toJson());
      if (credId == '') {
        var type = credential.type
            .firstWhere((element) => element != 'VerifiableCredential');
        credId = '${credential.issuanceDate.toIso8601String()}$type';
      }
      var historyEntries = wallet.historyEntriesForCredential(credId);
      List<Widget> entries = [];

      for (var h in historyEntries) {
        var tile = ListTile(
          leading: Text(
              '${h.timestamp.day}.${h.timestamp.month}.${h.timestamp.year}, ${h.timestamp.hour}:${h.timestamp.minute}'),
          title: Text(h.action == 'issue'
              ? AppLocalizations.of(context)!.issued
              : h.action == 'present'
                  ? AppLocalizations.of(context)!.presented
                  : AppLocalizations.of(context)!.presentedError),
        );
        entries.add(tile);
      }
      return ExpansionTile(
        title: Text(AppLocalizations.of(context)!.history),
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
        title: Text(AppLocalizations.of(context)!.delete),
        content: Card(child: Text(AppLocalizations.of(context)!.deletionNote)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
              onPressed: () async {
                var credId = widget.credential.id ??
                    getHolderDidFromCredential(widget.credential.toJson());
                if (credId == '') {
                  var type = widget.credential.type.firstWhere(
                      (element) => element != 'VerifiableCredential');
                  credId =
                      '${widget.credential.issuanceDate.toIso8601String()}$type';
                }
                wallet.deleteCredential(credId);
                Navigator.of(context).pop();
                //Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => const CredentialPage()));
              },
              child: Text(AppLocalizations.of(context)!.delete))
        ],
      ),
    );
  }

  List<Widget> _buildOtherData() {
    var otherData = <Widget>[];

    var issDateValue = widget.credential.issuanceDate;
    var issDate = ListTile(
        subtitle: Text(AppLocalizations.of(context)!.issuanceDate),
        title: Text(
            '${issDateValue.day.toString().padLeft(2, '0')}. ${issDateValue.month.toString().padLeft(2, '0')}. ${issDateValue.year}'));
    otherData.add(issDate);

    var expDate = widget.credential.expirationDate;
    if (expDate != null) {
      var expDateTile = ListTile(
          subtitle: Text(AppLocalizations.of(context)!.expirationDate),
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
          statusText = AppLocalizations.of(context)!.valid;
          break;
        case 1:
          statusText = AppLocalizations.of(context)!.expired;
          break;
        case 2:
          statusText = AppLocalizations.of(context)!.inactive;
          break;
        case 3:
          statusText = AppLocalizations.of(context)!.revoked;
          break;
        default:
          statusText = AppLocalizations.of(context)!.unknown;
          break;
      }
      return ListTile(
        subtitle: Text(AppLocalizations.of(context)!.state),
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
        issuer.add(Text(AppLocalizations.of(context)!.verifiedBy));

        var dnIss = {
          for (var item in cert.tbsCertificate.issuer!.names)
            item.keys.first.name: item.values.first
        };
        issuer.addAll(buildCredSubject(dnIss));
      } else {
        issuer += buildCredSubject(issMap);
      }
    } else if (widget.credential.isSelfIssued()) {
      issuer.add(Text(AppLocalizations.of(context)!.selfIssued));
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
          title: Text(AppLocalizations.of(context)!.invoice),
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
      title: Text(AppLocalizations.of(context)!.personnelData),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: buildCredSubject(widget.credential.credentialSubject),
    );
    var otherData = ExpansionTile(
      title: Text(AppLocalizations.of(context)!.otherData),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: _buildOtherData(),
    );
    var issuerData = ExpansionTile(
      title: Text(AppLocalizations.of(context)!.issuer),
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
        HistoryEntries(credential: widget.credential)
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
            onPressed: getHolderDidFromCredential(widget.credential.toJson()) ==
                    ''
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => StyledScaffoldTitle(
                        title:
                            AppLocalizations.of(context)!.sellCredentialTitle,
                        scanOnTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const QrScanner())),
                        child: Consumer<WalletProvider>(
                            builder: (context, wallet, child) {
                          return TopUp(
                              paymentMethods: wallet.paymentCredentials,
                              onTopUpSats: (amount, memo, vc) =>
                                  Navigator.of(context)
                                      .pushReplacement(MaterialPageRoute(
                                          builder: (context) => QrRender(
                                                credential: widget.credential,
                                                amount: amount,
                                                memo: memo,
                                              ))),
                              onTopUpFiat: (x) {});
                        }))))
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        QrRender(credential: widget.credential))),
            child: Text(
                getHolderDidFromCredential(widget.credential.toJson()) == ''
                    ? AppLocalizations.of(context)!.forSale
                    : AppLocalizations.of(context)!.forShow)),
        TextButton(
            onPressed: _deleteCredential,
            child: Text(AppLocalizations.of(context)!.delete))
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
