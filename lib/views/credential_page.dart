import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/property_names.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:json_path/fun_sdk.dart';
import 'package:json_path/json_path.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class CredentialPage extends StatefulWidget {
  final String initialSelection;

  const CredentialPage({super.key, required this.initialSelection});

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
                      var id = getHolderDidFromCredential(cred.toJson());
                      if (id == '') {
                        id = '${cred.issuanceDate.toIso8601String()}$type';
                      }

                      if (type != 'PaymentReceipt') {
                        return Column(children: [
                          CredentialCard(
                            credential: cred,
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
        var index = 0;
        var primitiveString = '';
        for (var v in value) {
          if (v is Map) {
            List<Widget> subs =
                buildCredSubject(v.cast<String, dynamic>(), '$key.$index');
            children.addAll(subs);
          } else if (v is List) {
            List<Widget> subs = buildCredSubject({index.toString(): v}, key);
            children.addAll(subs);
          } else {
            primitiveString += '${uriDecode(v)}, ';
          }
          index++;
        }
        if (primitiveString.isNotEmpty) {
          children.add(generateTile(before, key,
              primitiveString.substring(0, primitiveString.length - 2)));
        }
      } else {
        children.add(generateTile(before, key, value));
      }
    }
  });
  return children;
}

ListTile generateTile(String? before, String key, dynamic value) {
  var subtitle = '${before != null ? '$before.' : ''}$key';
  var title = (value is String && value.startsWith('data:'))
      ? InkWell(
          child: Text(AppLocalizations.of(navigatorKey.currentContext!)!.show),
          onTap: () {
            if (value.contains('image')) {
              Navigator.of(navigatorKey.currentContext!).push(MaterialPageRoute(
                  builder: (context) =>
                      Base64ImagePreview(imageDataUri: value)));
            } else if (value.contains('application/pdf')) {
              Navigator.of(navigatorKey.currentContext!).push(MaterialPageRoute(
                  builder: (context) => Base64PdfPreview(pdfDataUri: value)));
            }
          },
        )
      : value is String
          ? Text(uriDecode(value))
          : Text(value.toString());

  return ListTile(
    visualDensity: const VisualDensity(horizontal: 0, vertical: -2.5),
    leading: Container(
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
      child: Text(
        propertyNames[subtitle] ?? subtitle,
      ),
    ),
    minLeadingWidth: 100,
    titleAlignment: ListTileTitleAlignment.center,
    leadingAndTrailingTextStyle: const TextStyle(color: Colors.black38),
    title: title,
  );
}

dynamic uriDecode(dynamic value) {
  try {
    return Uri.decodeFull(value);
  } catch (_) {
    return value;
  }
}

class Base64ImagePreview extends StatelessWidget {
  final String imageDataUri;

  const Base64ImagePreview({super.key, required this.imageDataUri});

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

  const Base64PdfPreview({super.key, required this.pdfDataUri});

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

class ContextCard extends StatefulWidget {
  final VerifiableCredential context;
  final String? background;

  const ContextCard({super.key, required this.context, this.background});

  @override
  State<ContextCard> createState() => ContextCardState();
}

class ContextCardState extends State<ContextCard> {
  bool back = false;

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
                var credId = widget.context.id ??
                    getHolderDidFromCredential(widget.context.toJson());
                if (credId == '') {
                  var type = getTypeToShow(widget.context.type);
                  credId =
                      '${widget.context.issuanceDate.toIso8601String()}$type';
                }
                wallet.deleteCredential(credId);
                wallet.removeFromFavorites(credId);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text(AppLocalizations.of(context)!.delete))
        ],
      ),
    );
  }

  Widget transitionBuilder(Widget widget, Animation<double> animation) {
    final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
    return AnimatedBuilder(
      animation: rotateAnim,
      child: widget,
      builder: (context, widget) {
        var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
        final isUnder = (ValueKey(back) != widget?.key);
        tilt *= isUnder ? -1.0 : 1.0;
        final value =
            isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
        return Transform(
            transform: (Matrix4.rotationY(value)..setEntry(3, 0, tilt)),
            alignment: Alignment.center,
            child: widget);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                CredentialPage(initialSelection: widget.context.id!))),
        child: Consumer<WalletProvider>(builder: (context, wallet, child) {
          return AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              transitionBuilder: transitionBuilder,
              switchInCurve: Curves.easeInBack,
              switchOutCurve: Curves.easeInBack.flipped,
              layoutBuilder: (widget, list) =>
                  Stack(children: [widget!, ...list]),
              child: back
                  ? widget.context.type.contains('PaymentContext')
                      ? PaymentCard(
                          key: const ValueKey(false),
                          deleteOnTap: _deleteCredential,
                          onUpdateTap: wallet.hasUpdate.contains(
                                  '${widget.context.credentialSubject['paymentType'] == 'LightningMainnetPayment' ? '2' : '3'}_${widget.context.id!}')
                              ? () async {
                                  var download = await get(Uri.parse(
                                      '$contextEndpoint&contextid=${widget.context.credentialSubject['paymentType'] == 'LightningMainnetPayment' ? '2' : '3'}'));
                                  if (download.statusCode == 200) {
                                    wallet.reIssuePaymentContext(widget.context,
                                        jsonDecode(download.body));
                                  }
                                }
                              : null,
                          onReturnTap: () => setState(() {
                            back = !back;
                          }),
                          balance: Provider.of<WalletProvider>(context,
                                      listen: false)
                                  .balance[widget.context.id]
                                  ?.toStringAsFixed(2) ??
                              '0.0',
                          cardTitle: widget.context.credentialSubject['name'],
                          cardTitleColor: widget.context
                                      .credentialSubject['overlaycolor'] !=
                                  null
                              ? HexColor.fromHex(widget
                                  .context.credentialSubject['overlaycolor'])
                              : Colors.black,
                          backgroundColor: widget.context
                                      .credentialSubject['backsidecolor'] !=
                                  null
                              ? HexColor.fromHex(widget
                                  .context.credentialSubject['backsidecolor'])
                              : const Color.fromARGB(255, 233, 224, 200),
                          subjectName: '',
                          bottomLeftText: const SizedBox(
                            width: 0,
                          ),
                          bottomRightText: const SizedBox(
                            width: 0,
                          ),
                        )
                      : ContextCredentialCardBack(
                          credential: widget.context,
                          key: const ValueKey(false),
                          deleteOnTap: _deleteCredential,
                          onUpdateTap: wallet.hasUpdate.contains(
                                  widget.context.credentialSubject['contextId'])
                              ? () async {
                                  var download = await get(Uri.parse(
                                      '$contextEndpoint&contextid=${widget.context.credentialSubject['contextId']}'));
                                  if (download.statusCode == 200) {
                                    issueContext(
                                        wallet,
                                        jsonDecode(download.body),
                                        widget.context
                                            .credentialSubject['contextId'],
                                        true);
                                  }
                                }
                              : null,
                          onReturnTap: () => setState(() {
                                back = !back;
                              }),
                          cardTitle: '',
                          cardTitleColor:
                              widget.context.credentialSubject['overlaycolor'] != null
                                  ? HexColor.fromHex(widget.context
                                      .credentialSubject['overlaycolor'])
                                  : Colors.black,
                          backgroundColor:
                              widget.context.credentialSubject['backsidecolor'] !=
                                      null
                                  ? HexColor.fromHex(widget.context
                                      .credentialSubject['backsidecolor'])
                                  : const Color.fromARGB(255, 233, 224, 200),
                          subjectName: widget.context.credentialSubject['name'],
                          bottomLeftText: const SizedBox(
                            width: 0,
                          ),
                          bottomRightText: const SizedBox(
                            width: 0,
                          ))
                  : ContextCredentialCard(
                      key: const ValueKey(true),
                      isFavorite: wallet.isFavorite(widget.context.id!),
                      addToFavorites: () {
                        wallet.isFavorite(widget.context.id!)
                            ? wallet.removeFromFavorites(widget.context.id!)
                            : wallet.addToFavorites(widget.context.id!);
                      },
                      onReturnTap: () => setState(() {
                            back = !back;
                          }),
                      cardTitle: '',
                      cardTitleColor:
                          widget.context.credentialSubject['overlaycolor'] != null
                              ? HexColor.fromHex(widget.context.credentialSubject['overlaycolor'])
                              : const Color.fromARGB(255, 255, 255, 255),
                      backgroundImage: widget.context.credentialSubject['backgroundImage'] != null
                          ? Image.memory(base64Decode(widget.context.credentialSubject['backgroundImage'].split(',').last)).image
                          : widget.context.credentialSubject['mainbgimg'] != null
                              ? Image.network(widget.context.credentialSubject['mainbgimg']).image
                              : null,
                      subjectName: widget.context.credentialSubject['name'],
                      bottomLeftText: const SizedBox(
                        width: 0,
                      ),
                      bottomRightText: const SizedBox(
                        width: 0,
                      )));
        }));
  }
}

class CredentialCard extends StatefulWidget {
  final VerifiableCredential credential;
  final String? background;
  final bool clickable;

  const CredentialCard(
      {super.key,
      required this.credential,
      this.background,
      this.clickable = true});

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

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onLongPress: () => widget.credential.type.contains('ContextCredential')
            ? Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    CredentialDetailView(credential: widget.credential)))
            : null,
        onTap: () => widget.clickable
            ? widget.credential.type.contains('ContextCredential')
                ? Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CredentialPage(
                        initialSelection: widget.credential.id!)))
                : Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        CredentialDetailView(credential: widget.credential)))
            : null,
        child: Consumer<WalletProvider>(builder: (context, wallet, child) {
          var id = getHolderDidFromCredential(widget.credential.toJson());
          var revState = wallet.revocationState[id];
          if (revState == RevocationState.expired.index ||
              revState == RevocationState.revoked.index ||
              revState == RevocationState.suspended.index) {
            return Container(
              foregroundDecoration: const BoxDecoration(
                  color: Color.fromARGB(125, 255, 255, 255)),
              child: IdCard.fromCredential(
                credential: widget.credential,
                wallet: wallet,
                background: widget.background,
              ),
            );
          } else {
            return IdCard.fromCredential(
              credential: widget.credential,
              wallet: wallet,
              background: widget.background,
            );
          }
        }));
  }
}
