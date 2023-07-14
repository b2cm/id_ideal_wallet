import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/property_names.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:json_path/fun_sdk.dart';
import 'package:json_path/json_path.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class CredentialPage extends StatefulWidget {
  final String initialSelection;

  const CredentialPage({Key? key, required this.initialSelection})
      : super(key: key);

  @override
  CredentialPageState createState() => CredentialPageState();
}

class CredentialPageState extends State<CredentialPage> {
  String currentSelection = 'all';

  @override
  void initState() {
    super.initState();
    currentSelection = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        var itemList = [
          DropdownMenuItem(
            value: 'all',
            child: Text(AppLocalizations.of(context)!.allCredentials),
          ),
          ...wallet.contextCredentials.map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(
                  e.credentialSubject['name'] ?? getTypeToShow(e.type),
                  maxLines: 2,
                ),
              ))
        ];

        var credentialList = currentSelection == 'all'
            ? wallet.credentials
            : wallet.getCredentialsForContext(currentSelection);
        return StyledScaffoldTitle(
            currentlyActive: 0,
            title: DropdownButton(
              isExpanded: true,
              value: currentSelection,
              items: itemList,
              onChanged: (String? value) {
                setState(() {
                  currentSelection = value!;
                });
              },
            ),
            appBarActions: [
              InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon')));
                  },
                  child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.search, size: 30)))
            ],
            child: credentialList.isEmpty
                ? Center(
                    child:
                        Text(AppLocalizations.of(context)!.noteNoCredentials))
                : ListView.builder(
                    itemCount: credentialList.length,
                    itemBuilder: (context, index) {
                      var cred = credentialList[index];
                      var type = getTypeToShow(cred.type);
                      var id =
                          cred.id ?? getHolderDidFromCredential(cred.toJson());
                      if (id == '') {
                        id = '${cred.issuanceDate.toIso8601String()}$type';
                      }

                      if (type != 'PaymentReceipt') {
                        return Column(children: [
                          CredentialCard(
                            credential: cred,
                            background: wallet
                                .getContextForCredential(id)
                                ?.credentialSubject['backgroundImage'],
                          ),
                          const SizedBox(
                            height: 10,
                          )
                        ]);
                      } else {
                        return const SizedBox(
                          height: 0,
                        );
                      }
                    }));
      } else {
        wallet.openWallet();
        return Scaffold(
          body: Center(
            child: Text(AppLocalizations.of(context)!.openWallet),
          ),
        );
      }
    });
  }
}

List<Widget> buildCredSubject(Map<String, dynamic> subject, [String? before]) {
  List<Widget> children = [];
  subject.forEach((key, value) {
    if (key != 'id') {
      if (value is Map<String, dynamic>) {
        List<Widget> subs = buildCredSubject(value, key);
        children.addAll(subs);
      } else if (value is List) {
      } else {
        var subtitle = '${before != null ? '$before.' : ''}$key';
        children.add(ListTile(
          subtitle: Text(propertyNames[subtitle] ?? subtitle),
          title: (value is String && value.startsWith('data:'))
              ? InkWell(
                  child: Text(
                      AppLocalizations.of(navigatorKey.currentContext!)!.show),
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
              : Text(value
                  .replaceAll('ae', 'ä')
                  .replaceAll('ue', 'ü')
                  .replaceAll('oe', 'ö')),
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
        title: AppLocalizations.of(context)!.preview,
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
      title: AppLocalizations.of(context)!.preview,
      child: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Credential',
        build: (context) => _makePdf(),
      ),
    );
  }
}

class IsPicture implements Fun1<bool, Maybe> {
  @override
  final name = 'is_picture';

  @override
  bool call(Maybe arg) => arg
      .type<String>() // Make sure it's a string
      .map((value) => value.startsWith('data:image'))
      .or(false); // for non-string values return false
}

class CredentialCard extends StatefulWidget {
  final VerifiableCredential credential;
  final String? background;

  const CredentialCard({Key? key, required this.credential, this.background})
      : super(key: key);

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
        final parser = JsonPathParser(functions: [IsPicture()]);
        final path = parser.parse(r'$.credentialSubject..[?image]');

        var result = path.read(widget.credential.toJson());
        logger.d(result.first.path);
        if (!result.first.path.contains('background')) {
          var dataString = result.first.value as String;
          var imageData = dataString.split(',').last;

          image = Image.memory(base64Decode(imageData));
        }
        setState(() {});
      }
    } catch (e) {
      logger.d('cant decode image: $e');
    }
  }

  Widget buildCard(WalletProvider wallet) {
    return widget.credential.type.contains('ContextCredential')
        ? widget.credential.type.contains('PaymentContext')
            ? PaymentCard(
                receiveOnTap: () {},
                sendOnTap: () {},
                balance:
                    wallet.balance[widget.credential.id]?.toStringAsFixed(2) ??
                        '0.0',
                cardTitle: widget.credential.credentialSubject['name'],
                subjectName: '',
                bottomLeftText: const SizedBox(
                  width: 0,
                ),
                bottomRightText: const SizedBox(
                  width: 0,
                ),
              )
            : ContextCredentialCard(
                cardTitle: '',
                backgroundImage: widget
                            .credential.credentialSubject['backgroundImage'] !=
                        null
                    ? Image.memory(base64Decode(widget.credential.credentialSubject['backgroundImage'].split(',').last))
                        .image
                    : null,
                subjectName: widget.credential.credentialSubject['name'],
                bottomLeftText: const SizedBox(
                  width: 0,
                ),
                bottomRightText: const SizedBox(
                  width: 0,
                ))
        : widget.credential.type.contains('MemberCard')
            ? MemberCard(
                barcodeType: widget.credential.credentialSubject['barcodeType'],
                memberNumber: widget.credential.credentialSubject['number'],
                cardTitle: widget.credential.credentialSubject['name'],
                subjectName: '',
                bottomLeftText: IssuerInfoText(
                    issuer: widget.credential.issuer,
                    selfIssued: widget.credential.isSelfIssued()),
                bottomRightText: IssuerInfoIcon(
                  issuer: widget.credential.issuer,
                  selfIssued: widget.credential.isSelfIssued(),
                ))
            : widget.credential.type.contains('ChallengeSolvedCredential') ||
                    widget.credential.type.contains('Losticket') ||
                    widget.credential.type.contains('JuniorDiplom')
                ? LNDWCard(
                    cardTitle:
                        widget.credential.credentialSubject['icon'] ?? '',
                    backgroundImage: widget.background != null
                        ? Image.memory(base64Decode(widget.background!.split(',').last))
                            .image
                        : null,
                    subjectName: widget.credential.credentialSubject['stand'] ??
                        getTypeToShow(widget.credential.type),
                    bottomLeftText: const SizedBox(
                      width: 0,
                    ),
                    bottomRightText: const SizedBox(
                      width: 0,
                    ))
                : IdCard(
                    subjectImage: image?.image,
                    backgroundImage: widget.background != null
                        ? Image.memory(base64Decode(widget.background!.split(',').last))
                            .image
                        : null,
                    cardTitle: getTypeToShow(widget.credential.type),
                    subjectName:
                        '${widget.credential.credentialSubject['givenName'] ?? widget.credential.credentialSubject['name'] ?? ''} ${widget.credential.credentialSubject['familyName'] ?? ''}',
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
        onLongPress: () => widget.credential.type.contains('ContextCredential')
            ? Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    CredentialDetailView(credential: widget.credential)))
            : null,
        onTap: () => widget.credential.type.contains('ContextCredential')
            ? Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    CredentialPage(initialSelection: widget.credential.id!)))
            : Navigator.of(context).push(MaterialPageRoute(
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
              child: buildCard(wallet),
            );
          } else {
            return buildCard(wallet);
          }
        }));
  }
}
