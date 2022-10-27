import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/views/show_propose_presentation_code.dart';
import 'package:x509b/x509.dart' as x509;

class CredentialDetailView extends StatefulWidget {
  final WalletStore wallet;
  final VerifiableCredential credential;

  const CredentialDetailView(
      {Key? key, required this.wallet, required this.credential})
      : super(key: key);

  @override
  _CredentialDetailState createState() => _CredentialDetailState();
}

class _CredentialDetailState extends State<CredentialDetailView> {
  void _deleteCredential() {
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
                await widget.wallet.deleteCredential(widget.credential.id ??
                    getHolderDidFromCredential(widget.credential.toJson()));
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (context) => MainPage(wallet: widget.wallet)));
              },
              child: const Text('Löschen'))
        ],
      ),
    );
  }

  List<Widget> _buildOtherData() {
    var otherData = <Widget>[];
    var issDateValue = widget.credential.issuanceDate;
    var issDate = Text(
        'Ausstelldatum: ${issDateValue.day.toString().padLeft(2, '0')}. ${issDateValue.month.toString().padLeft(2, '0')}. ${issDateValue.year}');
    otherData.add(issDate);
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
    } else {
      //issuer is String
      issuer.add(Text(widget.credential.issuer));
    }

    return issuer;
  }

  List<Widget> _buildHistory() {
    var historyEntries = widget.wallet.getExchangeHistoryEntriesForCredential(
        getHolderDidFromCredential(widget.credential.toJson()));
    List<Widget> entries = [];
    if (historyEntries != null) {
      for (var h in historyEntries) {
        var tile = ListTile(
          leading: Text(
              '${h.timestamp.day}.${h.timestamp.month}.${h.timestamp.year}, ${h.timestamp.hour}:${h.timestamp.minute}'),
          title: Text(h.action == 'issue' ? 'Ausgestellt' : 'Vorgezeigt'),
        );
        entries.add(tile);
      }
    }
    return entries;
  }

  Widget _buildBody() {
    var personalData = ExpansionTile(
      title: const Text('Persönliche Daten'),
      children: buildCredSubject(widget.credential.credentialSubject),
      childrenPadding: const EdgeInsets.all(10),
    );
    var otherData = ExpansionTile(
      title: const Text('Sonstige Daten'),
      children: _buildOtherData(),
      childrenPadding: const EdgeInsets.all(10),
    );
    var issuerData = ExpansionTile(
      title: const Text('Aussteller'),
      children: _buildIssuerData(),
      childrenPadding: const EdgeInsets.all(10),
    );
    var history = ExpansionTile(
      title: const Text('Historie'),
      children: _buildHistory(),
      childrenPadding: const EdgeInsets.all(10),
    );
    return Column(
      children: [personalData, issuerData, otherData, history],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.credential.type
            .firstWhere((element) => element != 'VerifiableCredential')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: _deleteCredential,
              child: const Icon(Icons.delete_forever),
            ),
          )
        ],
      ),
      body: _buildBody(),
      persistentFooterButtons: [
        TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => QrRender(
                    credential: widget.credential, wallet: widget.wallet))),
            child: const Text('zum Vorzeigen anbieten'))
      ],
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }
}
