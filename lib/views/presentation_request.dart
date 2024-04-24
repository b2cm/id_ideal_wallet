import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/basicUi/standard/requester_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/secured_widget.dart';
import 'package:id_ideal_wallet/constants/kaprion_context.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/self_issuance.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../functions/didcomm_message_handler.dart';

class PresentationRequestDialog extends StatefulWidget {
  final List<FilterResult> results;
  final String? name, purpose;
  final String myDid;
  final String otherEndpoint;
  final String receiverDid;
  final String definitionHash;
  final RequestPresentation? message;
  final bool isOidc, askForBackground;
  final String? nonce, oidcState, oidcResponseMode;
  final String? lnInvoice;
  final Map<String, dynamic>? lnInvoiceRequest;
  final List<VerifiableCredential>? paymentCards;

  const PresentationRequestDialog(
      {super.key,
      required this.results,
      required this.receiverDid,
      required this.myDid,
      required this.otherEndpoint,
      required this.definitionHash,
      this.askForBackground = false,
      this.name,
      this.purpose,
      this.message,
      this.isOidc = false,
      this.nonce,
      this.lnInvoice,
      this.lnInvoiceRequest,
      this.paymentCards,
      this.oidcResponseMode,
      this.oidcState});

  @override
  PresentationRequestDialogState createState() =>
      PresentationRequestDialogState();
}

class PresentationRequestDialogState extends State<PresentationRequestDialog> {
  //'Database' for Checkboxes
  Map<String, bool> selectedCredsPerResult = {};
  bool dataEntered = true;
  bool send = false;
  bool fulfillable = true;
  bool backgroundAllow = true;
  String amount = '';

  @override
  initState() {
    super.initState();
    int outerPos = 0;
    int innerPos = 0;
    for (var res in widget.results) {
      innerPos = 0;
      for (var _ in res.credentials) {
        if (innerPos == 0) {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        } else {
          if (res.submissionRequirement?.min != null &&
              innerPos < res.submissionRequirement!.min!) {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
          } else {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
          }
        }
        innerPos++;
      }
      outerPos++;
    }

    getAmount();
  }

  Future<void> getAmount() async {
    if (widget.lnInvoice != null && widget.paymentCards != null) {
      var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
          listen: false);
      var paymentId = widget.paymentCards!.first.id!;
      var lnInKey = wallet.getLnInKey(paymentId);
      var i = await decodeInvoice(lnInKey!, widget.lnInvoice!);
      amount = i.amount.toSat().toStringAsFixed(2);
      logger.d(amount);
      setState(() {});
    }
  }

  List<Widget> buildChilds() {
    List<Widget> childList = [];
    int outerPos = 0;
    int innerPos = 0;
    fulfillable = true;

    //overall name
    if (widget.name != null) {
      childList.add(
        Text(
          widget.name!,
          style: Theme.of(context).primaryTextTheme.headlineLarge,
        ),
      );
      childList.add(const SizedBox(
        height: 10,
      ));
    }

    // Requesting entity
    childList.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: RequesterInfo(
          requesterUrl: widget.otherEndpoint,
          followingText:
              ' ${AppLocalizations.of(navigatorKey.currentContext!)!.noteGetInformation}:',
        ),
      ),
    );
    childList.add(const SizedBox(
      height: 10,
    ));

    if (widget.askForBackground) {
      childList.add(CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.backgroundPresentation),
          subtitle: Text(AppLocalizations.of(context)!
              .backgroundPresentationNote(widget.otherEndpoint)),
          value: backgroundAllow,
          onChanged: (newValue) {
            if (newValue != null) {
              backgroundAllow = newValue;
              setState(() {});
            }
          }));
      childList.add(const SizedBox(
        height: 10,
      ));
    }

    for (var result in widget.results) {
      var outerTileChildList = <Widget>[];
      var outerTileExpanded = false;

      if (result.selfIssuable != null && result.selfIssuable!.isNotEmpty) {
        var pos = outerPos;
        dataEntered = false;
        if (result.credentials.isNotEmpty) {
          dataEntered = true;
        }
        for (var i in result.selfIssuable!) {
          outerTileExpanded = true;
          outerTileChildList.add(
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              child: ElevatedButton(
                onPressed: () async {
                  Map res;
                  int index;
                  (res, index) = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CredentialSelfIssue(
                        input: [i],
                        outerPos: pos,
                      ),
                    ),
                  );
                  if (res.isNotEmpty) {
                    var wallet = Provider.of<WalletProvider>(
                        navigatorKey.currentContext!,
                        listen: false);
                    var did = await wallet.newCredentialDid();

                    var credSubject = <dynamic, dynamic>{'id': did};
                    credSubject.addAll(res);
                    var cred = VerifiableCredential(
                        context: [
                          credentialsV1Iri,
                          'https://schema.org',
                          ed25519ContextIri
                        ],
                        type: [
                          'VerifiableCredential',
                          'SelfIssuedCredential'
                        ],
                        id: did,
                        issuer: did,
                        credentialSubject: credSubject,
                        issuanceDate: DateTime.now());
                    var signed = await signCredential(wallet.wallet, cred);
                    logger.d(signed);
                    widget.results[index].selfIssuable!.remove(i);
                    if (widget.results[index].selfIssuable!.isEmpty) {
                      widget.results[index].selfIssuable = null;
                    }
                    widget.results[index].credentials
                        .add(VerifiableCredential.fromJson(signed));
                    logger.d(widget.results);
                    selectedCredsPerResult[
                            'o${pos}i${widget.results[index].credentials.length - 1}'] =
                        true;
                    dataEntered = true;
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: Text(AppLocalizations.of(navigatorKey.currentContext!)!
                    .enterData),
              ),
            ),
          );
        }

        if (result.credentials.isNotEmpty) {
          outerTileChildList.add(const Text(
            'oder',
            style: TextStyle(fontWeight: FontWeight.bold),
          ));
        }
      }
      int credCount = result.selfIssuable?.length ?? 0;
      var selectedCredNames = <String>[];
      innerPos = 0;
      for (var v in result.credentials) {
        var key = 'o${outerPos}i$innerPos';
        logger.d(key);
        if (selectedCredsPerResult[key]!) {
          credCount++;
          selectedCredNames.add(getTypeToShow(v.type));
        }
        outerTileChildList.add(
          ExpansionTile(
            leading: Checkbox(
                activeColor: Colors.greenAccent.shade700,
                onChanged: (bool? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = newValue;
                    }
                  });
                },
                value: selectedCredsPerResult[key]),
            title: Text(getTypeToShow(v.type)),
            children: buildCredSubject(v.credentialSubject),
          ),
        );
        innerPos++;
      }

      if (!result.fulfilled) {
        logger.d('entirely not');
        fulfillable = false;
      }

      var minCount = result.submissionRequirement?.min ??
          result.submissionRequirement?.count ??
          1;
      if (credCount < minCount) {
        logger.d('less creds: $credCount < $minCount');
        fulfillable = false;
      }

      var outerTile = ExpansionTile(
        initiallyExpanded: outerTileExpanded,
        title: SizedBox(
          child: RichText(
            text: TextSpan(
                style: Theme.of(context).primaryTextTheme.bodyMedium,
                children: [
                  TextSpan(
                      text:
                          '${credCount - (result.selfIssuable?.length ?? 0)} / $minCount ',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium!
                          .copyWith(
                            color: result.fulfilled
                                ? Colors.greenAccent.shade700
                                : Colors.red,
                          )),
                  TextSpan(
                      text: result.submissionRequirement?.name ??
                          selectedCredNames.toSet().join(', '))
                ]),
          ),
        ),
        subtitle: result.submissionRequirement?.purpose != null
            ? Text(
                result.submissionRequirement!.purpose!,
                style: Theme.of(context).primaryTextTheme.bodySmall,
              )
            : null,
        children: outerTileChildList,
      );
      childList.add(outerTile);
      outerPos++;
    }

    // overall purpose
    if (widget.purpose != null) {
      childList.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: RequesterInfo(
                  requesterUrl: widget.otherEndpoint,
                  followingText:
                      ' ${AppLocalizations.of(context)!.notePresentationPurpose}:\n${widget.purpose}'),
            ),
          ),
        ),
      );
    }

    if (widget.lnInvoice != null) {
      childList.add(const SizedBox(
        height: 10,
      ));
      childList.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade200,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).primaryTextTheme.titleMedium,
                children: [
                  TextSpan(
                    text: AppLocalizations.of(navigatorKey.currentContext!)!
                        .paymentInformation,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  WidgetSpan(
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 1,
                        bottom: 5,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 18,
                        // color: Colors.redAccent.shade700,
                      ),
                    ),
                  ),
                  TextSpan(
                      text:
                          '\n${AppLocalizations.of(navigatorKey.currentContext!)!.paymentInformationDetail}',
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                  TextSpan(
                      text: '$amount sat',
                      style: Theme.of(context).primaryTextTheme.titleLarge),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    if (widget.lnInvoiceRequest != null) {
      childList.add(const SizedBox(
        height: 10,
      ));
      childList.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade200,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).primaryTextTheme.titleMedium,
                children: [
                  const TextSpan(
                    text: 'Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                      text:
                          '\n${AppLocalizations.of(navigatorKey.currentContext!)!.funding1}',
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                  TextSpan(
                      text: ' ${widget.lnInvoiceRequest?['amount']} sat ',
                      style: Theme.of(context).primaryTextTheme.titleLarge),
                  TextSpan(
                      text: AppLocalizations.of(navigatorKey.currentContext!)!
                          .funding2,
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return childList;
  }

  Future<VerifiablePresentation?> sendAnswer() async {
    setState(() {
      send = true;
    });
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    if (widget.askForBackground && backgroundAllow) {
      wallet.addAuthorizedApp(widget.otherEndpoint, widget.definitionHash);
    }
    List<dynamic> finalSend = [];
    Set<String> issuerDids = {};
    int outerPos = 0;
    int innerPos = 0;
    for (var result in widget.results) {
      List<VerifiableCredential> credList = [];
      innerPos = 0;
      for (var cred in result.credentials) {
        if (selectedCredsPerResult['o${outerPos}i$innerPos']!) {
          credList.add(cred);
          issuerDids.add(getIssuerDidFromCredential(cred.toJson()));
        }
        innerPos++;
      }
      outerPos++;
      finalSend.add(FilterResult(
          credentials: credList,
          matchingDescriptorIds: result.matchingDescriptorIds,
          presentationDefinitionId: result.presentationDefinitionId,
          submissionRequirement: result.submissionRequirement));
    }
    // logger.d(issuerDids);
    // Set<String> addedCredentials = {};
    // for (var d in issuerDids) {
    //   var entry = wallet.getConfig('certCreds:$d');
    //   if (entry != null) {
    //     logger.d(entry);
    //     var j = jsonDecode(entry) as List;
    //     for (var c in j) {
    //       var cred = VerifiableCredential.fromJson(c);
    //       if (!addedCredentials.contains(cred.id)) {
    //         finalSend.add(cred);
    //         addedCredentials.add(cred.id!);
    //         logger.d(c);
    //       }
    //     }
    //   }
    // }
    //
    // logger.d('collected Credentials');

    if (widget.isOidc) {
      var vp = await buildPresentation(finalSend, wallet.wallet, widget.nonce!,
          loadDocumentFunction: loadDocumentFast);
      var casted = VerifiablePresentation.fromJson(vp);
      logger.d(await verifyPresentation(vp, widget.nonce!,
          loadDocumentFunction: loadDocumentFast));
      logger.d(jsonDecode(vp));
      logger.d('send presentation to ${widget.otherEndpoint}');
      Response res;
      if (widget.oidcResponseMode == 'direct_post') {
        res = await post(Uri.parse(widget.otherEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'presentation_submission=${casted.presentationSubmission!.toString()}&vp_token=$vp${widget.oidcState != null ? '&state=${widget.oidcState!}' : ''}');
      } else {
        logger.d(
            '${widget.otherEndpoint}?presentation_submission=${Uri.encodeQueryComponent(casted.presentationSubmission!.toString())}&vp_token=${Uri.encodeQueryComponent(vp)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}');

        var r = await launchUrl(
            Uri.parse(
                '${widget.otherEndpoint}?presentation_submission=${Uri.encodeQueryComponent(casted.presentationSubmission!.toString())}&vp_token=${Uri.encodeQueryComponent(vp)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}'),
            mode: LaunchMode.externalApplication);
        if (r) {
          res = Response('', 200);
        } else {
          res = Response('', 400);
        }
      }

      logger.d(res.statusCode);
      logger.d(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        for (var cred in casted.verifiableCredential!) {
          wallet.storeExchangeHistoryEntry(
              getHolderDidFromCredential(cred.toJson()),
              DateTime.now(),
              'present',
              widget.receiverDid);
        }

        String type = '';
        for (var c in casted.verifiableCredential!) {
          type += '''${getTypeToShow(c.type)}, \n''';
        }
        type = type.substring(0, type.length - 3);

        await showModalBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline: AppLocalizations.of(navigatorKey.currentContext!)!
                      .presentationSuccessful,
                  success: true,
                  amount: CurrencyDisplay(
                      amount: type,
                      symbol: '',
                      mainFontSize: 18,
                      centered: true),
                ),
              );
            });
        //Navigator.of(context).pop();
      } else {
        for (var cred in casted.verifiableCredential!) {
          wallet.storeExchangeHistoryEntry(
              getHolderDidFromCredential(cred.toJson()),
              DateTime.now(),
              'present failed',
              widget.receiverDid);
        }

        await showModalBottomSheet(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10))),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                closeSeconds: 4,
                child: PaymentFinished(
                  headline: AppLocalizations.of(navigatorKey.currentContext!)!
                      .presentationFailed,
                  success: false,
                  amount: const CurrencyDisplay(
                      width: 350,
                      amount: '',
                      symbol: '',
                      mainFontSize: 18,
                      centered: true),
                ),
              );
            });
        // Navigator.of(context).pop();
      }
      return VerifiablePresentation.fromJson(vp);
    } else {
      var vp = await buildPresentation(
          finalSend,
          wallet.wallet,
          widget.message?.presentationDefinition.first.challenge ??
              widget.nonce ??
              '',
          loadDocumentFunction: loadDocumentKaprion);
      if (widget.message != null) {
        var presentationMessage = Presentation(
            replyUrl: '$relay/buffer/${widget.myDid}',
            returnRoute: ReturnRouteValue.thread,
            to: [widget.receiverDid],
            from: widget.myDid,
            verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
            threadId: widget.message!.threadId ?? widget.message!.id,
            parentThreadId: widget.message!.parentThreadId);
        logger.d(widget.lnInvoiceRequest);
        logger.d(widget.paymentCards);
        if (widget.lnInvoiceRequest != null && widget.paymentCards != null) {
          logger.d('generate invoice');
          var paymentId = widget.paymentCards!.first.id!;
          var lnInKey = wallet.getLnInKey(paymentId);
          var paymentType =
              widget.paymentCards!.first.credentialSubject['paymentType'];
          var invoice = await createInvoice(
              lnInKey!,
              SatoshiAmount.fromUnitAndValue(
                  widget.lnInvoiceRequest!['amount'], SatoshiUnit.sat),
              memo: widget.lnInvoiceRequest!['memo'] ?? '',
              isMainnet: paymentType == 'LightningMainnetPayment');
          var index = invoice['checking_id'];
          logger.d(index);
          wallet.newPayment(
            paymentId,
            index,
            widget.lnInvoiceRequest!['memo'] ?? '',
            SatoshiAmount.fromUnitAndValue(
                widget.lnInvoiceRequest!['amount'], SatoshiUnit.sat),
          );

          var paymentAtt = Attachment(
              format: 'lnInvoice',
              data: AttachmentData(json: {
                'type': 'lnInvoice',
                'lnInvoice': invoice['payment_request']
              }));

          presentationMessage.attachments?.add(paymentAtt);
        }
        sendMessage(widget.myDid, widget.otherEndpoint, wallet,
            presentationMessage, widget.receiverDid,
            lnInvoice: widget.lnInvoice, paymentCards: widget.paymentCards);
      }

      for (var cred
          in VerifiablePresentation.fromJson(vp).verifiableCredential ?? []) {
        wallet.storeExchangeHistoryEntry(
            getHolderDidFromCredential(cred.toJson()),
            DateTime.now(),
            'present',
            widget.receiverDid);
      }

      // Navigator.of(context).pop();
      return VerifiablePresentation.fromJson(vp);
    }
  }

  void reject() async {
    logger.d('user declined presentation');
    if (widget.message != null) {
      var problem = ProblemReport(
          replyUrl: '$relay/buffer/${widget.myDid}',
          returnRoute: ReturnRouteValue.thread,
          to: [widget.receiverDid],
          from: widget.myDid,
          parentThreadId: widget.message!.threadId ?? widget.message!.id,
          code: 'e.p.user.decline');

      // TODO sendMessage(
      //     widget.myDid,
      //     widget.otherEndpoint,
      //     Provider.of<WalletProvider>(navigatorKey.currentContext!,
      //         listen: false),
      //     problem,
      //     widget.receiverDid);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SecuredWidget(
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: buildChilds(),
                ),
              ),
            ),
          ),
          persistentFooterButtons: [
            if (!dataEntered)
              FooterErrorText(
                  errorMessage: AppLocalizations.of(context)!.missingDataNote,
                  reject: reject)
            else if (!fulfillable)
              FooterErrorText(
                  errorMessage:
                      AppLocalizations.of(context)!.errorNotEnoughCredentials,
                  reject: reject)
            else
              FooterButtons(
                positiveText: widget.lnInvoice != null
                    ? AppLocalizations.of(context)!.orderWithPayment
                    : null,
                negativeFunction: reject,
                positiveFunction: () async {
                  var vp = await Future.delayed(
                      const Duration(milliseconds: 50), sendAnswer);
                  Navigator.of(context).pop(vp);
                },
              )
          ],
        ),
        if (send)
          const Opacity(
            opacity: 0.8,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (send)
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    child: Text(
                      '${AppLocalizations.of(context)!.waiting}\n${AppLocalizations.of(context)!.waitingSendPresentation}',
                    ))
              ],
            ),
          ),
      ],
    );
  }
}

class FooterErrorText extends StatelessWidget {
  final void Function() reject;
  final String errorMessage;

  const FooterErrorText(
      {super.key, required this.errorMessage, required this.reject});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).primaryTextTheme.titleMedium,
              children: [
                TextSpan(
                  text: AppLocalizations.of(context)!.attention,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                WidgetSpan(
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 1,
                      bottom: 5,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.redAccent.shade700,
                    ),
                  ),
                ),
                TextSpan(
                    text: '\n$errorMessage',
                    style: Theme.of(context).primaryTextTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        ElevatedButton(
            onPressed: reject,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(45),
            ),
            child: Text(AppLocalizations.of(context)!.cancel))
      ],
    );
  }
}
