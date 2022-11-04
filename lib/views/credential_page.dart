import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:provider/provider.dart';

class CredentialPage extends StatelessWidget {
  const CredentialPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffold(
        name: 'Max Mustermann',
        nameOnTap: () {},
        scanOnTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => const QrScanner()));
        },
        child: const CredentialOverview());
  }
}

List<Widget> buildCredSubject(Map<String, dynamic> subject, [String? before]) {
  List<Widget> children = [];
  subject.forEach((key, value) {
    if (key != 'id') {
      if (value is Map<String, dynamic>) {
        List<Widget> subs = buildCredSubject(value, key);
        children.addAll(subs);
      } else {
        children.add(Text('${before != null ? '$before.' : ''}$key: $value'));
      }
    }
  });
  return children;
}

class CredentialOverview extends StatelessWidget {
  const CredentialOverview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        var allCreds = wallet.allCredentials().values.toList();
        return ListView.builder(
            itemCount: allCreds.length,
            itemBuilder: (context, index) {
              var cred = allCreds[index].w3cCredential;
              if (cred != '') {
                return Column(children: [
                  CredentialCard(
                      credential: VerifiableCredential.fromJson(cred)),
                  const SizedBox(
                    height: 10,
                  )
                ]);
              } else {
                return const SizedBox(
                  height: 0,
                );
              }
            });
      } else {
        wallet.openWallet();
        return const Center(
          child: Text('Wallet Öffnen'),
        );
      }
    });
  }
}

class CredentialCard extends StatelessWidget {
  final VerifiableCredential credential;

  const CredentialCard({Key? key, required this.credential}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => CredentialDetailView(credential: credential))),
      child: IdCard(
          cardTitle: credential.type
              .firstWhere((element) => element != 'VerifiableCredential'),
          subjectName:
              '${credential.credentialSubject['givenName'] ?? ''} ${credential.credentialSubject['familyName'] ?? ''}',
          bottomLeftText: IssuerInfo(issuer: credential.issuer),
          bottomRightText: ''),
    );
  }
}
