import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/delete_dialog.dart';
import 'package:id_ideal_wallet/basicUi/standard/issuer_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_receipt_pdf.dart';
import 'package:provider/provider.dart';
import 'package:x509b/x509.dart' as x509;

import '../l10n/app_localizations.dart';

class HistoryEntries extends StatelessWidget {
  const HistoryEntries({super.key, required this.credential});

  final VerifiableCredential credential;

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      var credId = credential.credentialSubject['id'];
      if (credId == null || credId == '') {
        var type = getTypeToShow(credential.type);
        credId = '${credential.issuanceDate.toIso8601String()}$type';
      }
      var historyEntries = wallet.historyEntriesForCredential(credId);
      List<Widget> entries = [];

      for (var h in historyEntries) {
        logger.d(h.otherParty);
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
          subtitle: h.action == 'present' &&
                  h.otherParty.isNotEmpty &&
                  h.otherParty.startsWith('http')
              ? IssuerInfoText(issuer: '', endpoint: h.otherParty)
              : null,
        );
        entries.add(tile);
      }
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color.fromARGB(255, 122, 122, 122))),
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

class CredentialDetailView extends StatelessWidget {
  final VerifiableCredential credential;

  const CredentialDetailView({super.key, required this.credential});

  void _deleteCredential(BuildContext context) {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    showDialog(
        context: context,
        builder: (context) => DeleteDialog(
            deleteNote: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: AppLocalizations.of(context)!.deletionNote1,
                    style: Theme.of(context).primaryTextTheme.bodySmall),
                TextSpan(text: '\n\n'),
                WidgetSpan(
                  child: Container(
                    padding: const EdgeInsets.only(
                      right: 1,
                      bottom: 0,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.redAccent.shade700,
                    ),
                  ),
                ),
                TextSpan(
                    text: AppLocalizations.of(context)!.deletionNote2,
                    style: Theme.of(context).primaryTextTheme.titleMedium)
              ]),
            ),
            deleteFunction: () async {
              var credId = credential.credentialSubject['id'];
              if (credId == null || credId == '') {
                var type = getTypeToShow(credential.type);
                credId = '${credential.issuanceDate.toIso8601String()}$type';
              }
              wallet.deleteCredential(credId, true);
              Navigator.of(context).pop();
              if (credential.type.contains('ContextCredential')) {
                Provider.of<NavigationProvider>(context, listen: false)
                    .goBack();
              } else {
                Provider.of<NavigationProvider>(context, listen: false)
                    .goBack();
              }
            }));
  }

  Widget buildReceipt() {
    if (credential.credentialSubject is Map &&
        credential.credentialSubject.containsKey('receiptId')) {
      var receipt = Provider.of<WalletProvider>(navigatorKey.currentContext!,
              listen: false)
          .getCredential(credential.credentialSubject['receiptId']);
      if (receipt != null) {
        var receiptVc =
            VerifiableCredential.fromJson(receipt.verifiableCredential);
        var target = PdfPreviewPage(
            paymentReceipt: receiptVc,
            eventName: credential.credentialSubject['event'] ?? '');
        return ExpansionTile(
          title:
              Text(AppLocalizations.of(navigatorKey.currentContext!)!.invoice),
          trailing: InkWell(
              child: const Icon(Icons.picture_as_pdf),
              onTap: () => navigateClassic(target)),
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
            credential: credential,
            clickable: false,
          ),
          const SizedBox(
            height: 10,
          ),
          CredentialInfo(credential: credential),
          buildReceipt(),
          // issuerData,
          // otherData,
          const SizedBox(
            height: 10,
          ),
          HistoryEntries(credential: credential),
          const SizedBox(
            height: bottomPadding,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      useBackSwipe: false,
      title: '',
      appBarActions: [
        if (credential.expirationDate?.isBefore(DateTime.now()) ?? true)
          InkWell(
            onTap: () => _deleteCredential(context),
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.delete_outline_sharp, size: 30)),
          )
      ],
      child: _buildBody(),
    );
  }
}

class RefreshIcon extends StatefulWidget {
  final WalletProvider wallet;

  const RefreshIcon({super.key, required this.wallet});

  @override
  _RefreshIconState createState() => _RefreshIconState();
}

class _RefreshIconState extends State<RefreshIcon> {
  double _rotationAngle = 0.0;

  void _changeIconRotation() {
    setState(() {
      _rotationAngle += 1.0; // Full rotation
    });
    widget.wallet.checkValidity();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: _changeIconRotation,
        child: AnimatedRotation(
          turns: _rotationAngle,
          duration: const Duration(milliseconds: 750),
          child: const Icon(Icons.refresh, size: 25),
        ));
  }
}

class CredentialInfo extends StatelessWidget {
  final VerifiableCredential credential;
  final bool showStatus;

  const CredentialInfo(
      {super.key, required this.credential, this.showStatus = true});

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
        issuer += issMap['name'] ?? issMap['id'] ?? '';
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

    var id = credential.credentialSubject['id'];
    if (id == null || id == '') {
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
        trailing: RefreshIcon(wallet: wallet),
      );
    });
    if (showStatus) otherData.add(statusTile);

    return otherData;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color.fromARGB(255, 122, 122, 122)),
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
