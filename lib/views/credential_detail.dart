import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_receipt_pdf.dart';
import 'package:provider/provider.dart';
import 'package:x509b/x509.dart' as x509;

class HistoryEntries extends StatelessWidget {
  const HistoryEntries({super.key, required this.credential});

  final VerifiableCredential credential;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      var credId = getHolderDidFromCredential(credential.toJson());
      if (credId == '') {
        var type = getTypeToShow(credential.type);
        credId = '${credential.issuanceDate.toIso8601String()}$type';
      }
      var historyEntries = wallet.historyEntriesForCredential(credId);
      List<Widget> entries = [];

      for (var h in historyEntries) {
        var tile = ListTile(
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minLeadingWidth: 100,
          titleAlignment: ListTileTitleAlignment.center,
          leadingAndTrailingTextStyle: const TextStyle(color: Colors.black38),
          leading: Text(
              '${h.timestamp.day.toString().padLeft(2, '0')}.${h.timestamp.month.toString().padLeft(2, '0')}.${h.timestamp.year},\n${h.timestamp.hour.toString().padLeft(2, '0')}:${h.timestamp.minute.toString().padLeft(2, '0')}'),
          title: Text(h.action == 'issue'
              ? AppLocalizations.of(context)!.issued
              : h.action == 'add'
                  ? '${AppLocalizations.of(context)!.add}: ${h.otherParty}'
                  : h.action == 'update'
                      ? 'Update'
                      : h.action == 'present'
                          ? AppLocalizations.of(context)!.presented
                          : AppLocalizations.of(context)!.presentedError),
        );
        entries.add(tile);
      }
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // side: const BorderSide(color: Colors.black26)
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text(AppLocalizations.of(context)!.history),
          //childrenPadding: const EdgeInsets.all(10),
          children: entries,
        ),
      );
    });
  }
}

class CredentialDetailView extends StatefulWidget {
  final VerifiableCredential credential;

  const CredentialDetailView({super.key, required this.credential});

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
                var credId =
                    getHolderDidFromCredential(widget.credential.toJson());
                if (credId == '') {
                  var type = getTypeToShow(widget.credential.type);
                  credId =
                      '${widget.credential.issuanceDate.toIso8601String()}$type';
                }
                wallet.deleteCredential(credId);
                Navigator.of(context).pop();
                //Navigator.of(context).pop();
                if (widget.credential.type.contains('ContextCredential')) {
                  context.go('/');
                  ;
                } else {
                  Navigator.of(context).pop();
                  // Navigator.of(context).pushReplacement(MaterialPageRoute(
                  //     builder: (context) => const CredentialPage(
                  //           initialSelection: 'all',
                  //         )));
                }
              },
              child: Text(AppLocalizations.of(context)!.delete))
        ],
      ),
    );
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
    return SingleChildScrollView(
        child: Column(
      children: [
        CredentialCard(
          credential: widget.credential,
          clickable: false,
        ),
        const SizedBox(
          height: 10,
        ),
        CredentialInfo(credential: widget.credential),
        buildReceipt(),
        // issuerData,
        // otherData,
        const SizedBox(
          height: 10,
        ),
        HistoryEntries(credential: widget.credential)
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      useBackSwipe: false,
      title: '',
      appBarActions: [
        InkWell(
            onTap: _deleteCredential,
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.delete_outline_sharp, size: 30)))
      ],
      // footerButtons: [
      //   TextButton(
      //       onPressed: getHolderDidFromCredential(widget.credential.toJson()) ==
      //               ''
      //           ? () => Navigator.of(context).push(MaterialPageRoute(
      //               builder: (context) => StyledScaffoldTitle(
      //                   title:
      //                       AppLocalizations.of(context)!.sellCredentialTitle,
      //                   child: Consumer<WalletProvider>(
      //                       builder: (context, wallet, child) {
      //                     return TopUp(
      //                         paymentMethods: wallet.paymentCredentials,
      //                         onTopUpSats: (amount, memo, vc) =>
      //                             Navigator.of(context)
      //                                 .pushReplacement(MaterialPageRoute(
      //                                     builder: (context) => QrRender(
      //                                           credential: widget.credential,
      //                                           amount: amount,
      //                                           memo: memo,
      //                                         ))),
      //                         onTopUpFiat: (x) {});
      //                   }))))
      //           : () => Navigator.of(context).push(MaterialPageRoute(
      //               builder: (context) =>
      //                   QrRender(credential: widget.credential))),
      //       child: Text(
      //           getHolderDidFromCredential(widget.credential.toJson()) == ''
      //               ? AppLocalizations.of(context)!.forSale
      //               : AppLocalizations.of(context)!.forShow)),
      //   TextButton(
      //       onPressed: _deleteCredential,
      //       child: Text(AppLocalizations.of(context)!.delete))
      // ],
      child: _buildBody(),
    );
  }
}

class CredentialInfo extends StatelessWidget {
  final VerifiableCredential credential;

  const CredentialInfo({super.key, required this.credential});

  Text _buildIssuerData() {
    var issuer = '';
    if (credential.issuer is Map) {
      var issMap = credential.issuer as Map<String, dynamic>;
      if (issMap.containsKey('certificate')) {
        var certIt = x509.parsePem(
            '-----BEGIN CERTIFICATE-----\n${issMap['certificate']}\n-----END CERTIFICATE-----');
        var cert = certIt.first as x509.X509Certificate;
        var dn = {
          for (var item in cert.tbsCertificate.subject!.names)
            item.keys.first.name: item.values.first
        };
        // dn.remove('commonName');
        // issuer.addAll(buildCredSubject(dn));
        // issuer.add(const SizedBox(
        //   height: 10,
        // ));
        // issuer.add(Text(AppLocalizations.of(context)!.verifiedBy));
        issuer = dn['organizationName'] ?? dn['commonName'];
        //
        // var dnIss = {
        //   for (var item in cert.tbsCertificate.issuer!.names)
        //     item.keys.first.name: item.values.first
        // };
        // issuer.addAll(buildCredSubject(dnIss));
      } else {
        issuer += issMap['name'] ?? '';
      }
    } else if (credential.isSelfIssued()) {
      issuer = AppLocalizations.of(navigatorKey.currentContext!)!.selfIssued;
    } else {
      //issuer is String
      issuer = credential.issuer;
    }

    return Text(issuer);
  }

  List<Widget> _buildOtherData() {
    var otherData = <Widget>[];

    var issDateValue = credential.issuanceDate;
    var issDate = ListTile(
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        minLeadingWidth: 100,
        titleAlignment: ListTileTitleAlignment.center,
        leadingAndTrailingTextStyle: const TextStyle(color: Colors.black38),
        leading: Text(
            AppLocalizations.of(navigatorKey.currentContext!)!.issuanceDate),
        title: Text(
            '${issDateValue.day.toString().padLeft(2, '0')}. ${issDateValue.month.toString().padLeft(2, '0')}. ${issDateValue.year}'));
    otherData.add(issDate);

    var expDate = credential.expirationDate;
    if (expDate != null) {
      var expDateTile = ListTile(
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minLeadingWidth: 100,
          titleAlignment: ListTileTitleAlignment.center,
          leadingAndTrailingTextStyle: const TextStyle(color: Colors.black38),
          leading: Text(AppLocalizations.of(navigatorKey.currentContext!)!
              .expirationDate),
          title: Text(
            '${expDate.day.toString().padLeft(2, '0')}. ${expDate.month.toString().padLeft(2, '0')}. ${expDate.year}',
            style: expDate.isBefore(DateTime.now())
                ? const TextStyle(color: Colors.red)
                : null,
          ));
      otherData.add(expDateTile);
    }

    var id = getHolderDidFromCredential(credential.toJson());
    if (id == '') {
      var type = getTypeToShow(credential.type);
      id = '${credential.issuanceDate.toIso8601String()}$type';
    }
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
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        minLeadingWidth: 100,
        titleAlignment: ListTileTitleAlignment.center,
        leadingAndTrailingTextStyle: const TextStyle(color: Colors.black38),
        leading: Text(AppLocalizations.of(context)!.state),
        title: Text(statusText),
        trailing: InkWell(
          child: const Icon(Icons.refresh, size: 25),
          onTap: () => wallet.checkValidity(),
        ),
      );
    });
    otherData.add(statusTile);

    return otherData;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          //side: const BorderSide(color: Colors.black26)
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
            title: const Text(
              'Info',
            ),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...buildCredSubject(credential.credentialSubject),
              const Divider(
                color: Colors.black26,
                indent: 10,
                endIndent: 10,
                thickness: 1,
              ),
              ListTile(
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                minLeadingWidth: 100,
                titleAlignment: ListTileTitleAlignment.center,
                leadingAndTrailingTextStyle:
                    const TextStyle(color: Colors.black38),
                leading: Text(AppLocalizations.of(context)!.credential),
                title: Text(getTypeToShow(credential.type)),
              ),
              ListTile(
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                minLeadingWidth: 100,
                titleAlignment: ListTileTitleAlignment.center,
                leadingAndTrailingTextStyle:
                    const TextStyle(color: Colors.black38),
                leading: Text(AppLocalizations.of(context)!.issuer),
                title: _buildIssuerData(),
              ),
              const Divider(
                color: Colors.black26,
                indent: 10,
                endIndent: 10,
                thickness: 1,
              ),
              ..._buildOtherData(),
            ]));
  }
}
