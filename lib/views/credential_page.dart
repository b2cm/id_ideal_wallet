import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_name.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:json_path/json_path.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class CredentialPage extends StatelessWidget {
  const CredentialPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldName(
        name: 'Meine Credentials',
        nameOnTap: () => Navigator.of(context).pop(),
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
          title: (value is String && value.startsWith('data:'))
              ? InkWell(
                  child: const Text('Anzeigen'),
                  onTap: () {
                    if (value.contains('image')) {
                      Navigator.of(navigatorKey.currentContext!).push(
                          MaterialPageRoute(
                              builder: (context) =>
                                  Base64ImagePreview(imageDataUri: value)));
                    } else if (value.contains('application/pdf')) {
                      Navigator.of(navigatorKey.currentContext!).push(
                          MaterialPageRoute(
                              builder: (context) =>
                                  Base64PdfPreview(pdfDataUri: value)));
                    }
                  },
                )
              : Text(value),
        ));
      }
    }
  });
  return children;
}

class Base64ImagePreview extends StatelessWidget {
  final String imageDataUri;

  const Base64ImagePreview({Key? key, required this.imageDataUri})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        scanOnTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const QrScanner())),
        title: 'Vorschau',
        child: Image(
            image: Image.memory(base64Decode(imageDataUri.split(',').last))
                .image));
  }
}

class Base64PdfPreview extends StatelessWidget {
  final String pdfDataUri;

  const Base64PdfPreview({Key? key, required this.pdfDataUri})
      : super(key: key);

  FutureOr<Uint8List> _makePdf() {
    var base64 = pdfDataUri.split(',').last;
    return base64Decode(base64);
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      scanOnTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => const QrScanner())),
      title: 'Vorschau',
      child: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Credential',
        build: (context) => _makePdf(),
      ),
    );
  }
}

class CredentialOverview extends StatelessWidget {
  const CredentialOverview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        return ListView.builder(
            itemCount: wallet.credentials.length,
            itemBuilder: (context, index) {
              var cred = wallet.credentials[index];
              var type = cred.type
                  .firstWhere((element) => element != 'VerifiableCredential');
              if (type != 'PaymentReceipt') {
                return Column(children: [
                  CredentialCard(credential: cred),
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
      bool showImg = false;
      String imgB64 = '';

      widget.credential.credentialSubject.forEach((key, value) {
        // todo change key to picture
        if (key == 'data' &&
            value is String &&
            value.startsWith('data:image')) {
          showImg = true;
          imgB64 = value;
        }
      });

      if (showImg) {
        image = Image.memory(base64Decode(imgB64.split(',')[1]));
        setState(() {});
      } else {
        final path = JsonPath(r'$.credentialSubject..[?image]', filters: {
          'image': (match) =>
              match.value is String && match.value.startsWith('data:image')
        });

        var result = path.read(widget.credential.toJson());
        var dataString = result.first.value as String;
        var imageData = dataString.split(',').last;

        image = Image.memory(base64Decode(imageData));
        setState(() {});
      }
    } catch (e) {
      logger.d('cant decode image: $e');
    }
  }

  Widget buildCard() {
    return IdCard(
        subjectImage: image?.image,
        cardTitle: widget.credential.type
            .firstWhere((element) => element != 'VerifiableCredential'),
        subjectName:
            '${widget.credential.credentialSubject['givenName'] ?? ''} ${widget.credential.credentialSubject['familyName'] ?? ''}',
        bottomLeftText: IssuerInfoText(
            issuer: widget.credential.issuer,
            selfIssued: widget.credential.isSelfIssued()),
        bottomRightText: IssuerInfoIcon(
          issuer: widget.credential.issuer,
          selfIssued: widget.credential.isSelfIssued(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                CredentialDetailView(credential: widget.credential))),
        child: Consumer<WalletProvider>(builder: (context, wallet, child) {
          var id = widget.credential.id ??
              getHolderDidFromCredential(widget.credential.toJson());
          var revState = wallet.revocationState[id];
          if (revState == RevocationState.expired.index ||
              revState == RevocationState.revoked.index ||
              revState == RevocationState.suspended.index) {
            return Container(
              foregroundDecoration: const BoxDecoration(
                  color: Color.fromARGB(125, 255, 255, 255)),
              child: buildCard(),
            );
          } else {
            return buildCard();
          }
        }));
  }
}
