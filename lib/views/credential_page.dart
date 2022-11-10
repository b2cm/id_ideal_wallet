import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:json_path/json_path.dart';
import 'package:provider/provider.dart';

class CredentialPage extends StatelessWidget {
  const CredentialPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffold(
        name: 'Meine Credentials',
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
        children.add(ListTile(
          subtitle: Text('${before != null ? '$before.' : ''}$key'),
          title: Text(
              '${(value is String && value.startsWith('data:image')) ? '...' : value}'),
        ));
        // children.add(Text(
        //     '${before != null ? '$before.' : ''}$key: ${(value is String && value.startsWith('data:image')) ? '...' : value}'));
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

class CredentialCard extends StatefulWidget {
  final VerifiableCredential credential;

  const CredentialCard({Key? key, required this.credential}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CredentialCardState();
}

class CredentialCardState extends State<CredentialCard> {
  Image? image;

  @override
  void initState() {
    super.initState();
    searchImage();
  }

  Future<void> searchImage() async {
    try {
      final path = JsonPath(r'$.credentialSubject..[?image]', filters: {
        'image': (match) =>
            match.value is String && match.value.startsWith('data:image')
      });

      var result = path.read(widget.credential.toJson());
      var dataString = result.first.value as String;
      var imageData = dataString.split(',').last;

      image = Image.memory(base64Decode(imageData));
      setState(() {});
    } catch (e) {
      logger.e('cant decode image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              CredentialDetailView(credential: widget.credential))),
      child: IdCard(
          subjectImage: image?.image,
          cardTitle: widget.credential.type
              .firstWhere((element) => element != 'VerifiableCredential'),
          subjectName:
              '${widget.credential.credentialSubject['givenName'] ?? ''} ${widget.credential.credentialSubject['familyName'] ?? ''}',
          bottomLeftText: IssuerInfo(issuer: widget.credential.issuer),
          bottomRightText: ''),
    );
  }
}
