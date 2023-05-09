import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/self_issuance.dart';
import 'package:provider/provider.dart';

import '../functions/didcomm_message_handler.dart';

class RequesterInfo extends StatefulWidget {
  final String requesterUrl;

  const RequesterInfo({Key? key, required this.requesterUrl}) : super(key: key);

  @override
  State<StatefulWidget> createState() => RequesterInfoState();
}

class RequesterInfoState extends State<RequesterInfo> {
  String info = AppLocalizations.of(navigatorKey.currentContext!)!.anonymous;

  @override
  void initState() {
    super.initState();
    getInfo();
  }

  void getInfo() async {
    try {
      var certInfo = await getCertificateInfoFromUrl(widget.requesterUrl);
      info = certInfo?.subjectOrganization ??
          certInfo?.subjectCommonName ??
          AppLocalizations.of(navigatorKey.currentContext!)!.anonymous;
      setState(() {});
    } catch (e) {
      logger.d('Problem bei Zertifikatsabfrage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(info);
  }
}

class PresentationRequestDialog extends StatefulWidget {
  final List<FilterResult> results;
  final String myDid;
  final String otherEndpoint;
  final String receiverDid;
  final RequestPresentation? message;
  final bool isOidc;
  final String? nonce;

  const PresentationRequestDialog(
      {Key? key,
      required this.results,
      required this.receiverDid,
      required this.myDid,
      required this.otherEndpoint,
      this.message,
      this.isOidc = false,
      this.nonce})
      : super(key: key);

  @override
  _PresentationRequestDialogState createState() =>
      _PresentationRequestDialogState();
}

class _PresentationRequestDialogState extends State<PresentationRequestDialog> {
  //'Database' for Checkboxes
  Map<String, bool> selectedCredsPerResult = {};

  @override
  initState() {
    super.initState();
    int outerPos = 0;
    int innerPos = 0;
    for (var res in widget.results) {
      for (var c in res.credentials) {
        if (innerPos == 0) {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        } else {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
        }
        innerPos++;
      }
      outerPos++;
    }
  }

  List<Widget> buildChilds() {
    List<Widget> childList = [];
    int outerPos = 0;
    int innerPos = 0;

    // Requesting entity
    childList
        .add(Text(AppLocalizations.of(navigatorKey.currentContext!)!.dataFor));
    childList.add(RequesterInfo(requesterUrl: widget.otherEndpoint));
    childList.add(const SizedBox(
      height: 10,
    ));

    for (var result in widget.results) {
      bool all = false;

      if (result.submissionRequirement != null) {
        childList.add(Text(AppLocalizations.of(navigatorKey.currentContext!)!
            .reasonForRequest));
        childList.add(Text(result.submissionRequirement?.purpose ??
            result.submissionRequirement?.name ??
            'Default'));
        childList.add(const SizedBox(
          height: 10,
        ));

        if (result.submissionRequirement!.rule ==
            SubmissionRequirementRule.all) {
          all = true;
          childList
              .add(const Text('Wähle mindestens eins dieser Credentials aus'));
        } else {
          if (result.submissionRequirement!.count != null) {
            childList.add(Text(
                'Wähle ${result.submissionRequirement!.count!} Credential(s) aus'));
          } else if (result.submissionRequirement!.min != null) {
            childList.add(Text(
                'Wähle mindestens ${result.submissionRequirement!.min!} Credential(s) aus'));
          }
        }
      }

      if (result.selfIssuable != null && result.selfIssuable!.isNotEmpty) {
        var pos = outerPos;
        for (var i in result.selfIssuable!) {
          childList.add(Text(AppLocalizations.of(navigatorKey.currentContext!)!
              .selfIssueAllowed));
          childList.add(ElevatedButton(
              onPressed: () async {
                var res = await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CredentialSelfIssue(input: [i])));
                print(res);
                if (res != null) {
                  var wallet = Provider.of<WalletProvider>(
                      navigatorKey.currentContext!,
                      listen: false);
                  var did = await wallet.newCredentialDid();
                  if (res is Map) {
                    var credSubject = <dynamic, dynamic>{'id': did};
                    credSubject.addAll(res);
                    var cred = VerifiableCredential(
                        context: ['https://schema.org'],
                        type: ['SelfIssuedCredential'],
                        issuer: did,
                        credentialSubject: credSubject,
                        issuanceDate: DateTime.now());
                    var signed = await signCredential(wallet.wallet, cred);
                    logger.d(signed);
                    result.selfIssuable!.remove(i);
                    if (result.selfIssuable!.isEmpty) {
                      result.selfIssuable = null;
                    }
                    result.credentials
                        .add(VerifiableCredential.fromJson(signed));
                    selectedCredsPerResult[
                        'o${pos}i${result.credentials.length - 1}'] = true;
                    logger.d(selectedCredsPerResult);
                    setState(() {});
                  }
                }
              },
              child: Text(AppLocalizations.of(navigatorKey.currentContext!)!
                  .enterData)));
        }
      }

      for (var v in result.credentials) {
        var key = 'o${outerPos}i$innerPos';
        childList.add(
          ExpansionTile(
            leading: Checkbox(
                onChanged: (bool? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = newValue;
                    }
                  });
                },
                value: selectedCredsPerResult[key]),
            title: Text(v.type
                .firstWhere((element) => element != 'VerifiableCredential')),
            children: buildCredSubject(v.credentialSubject),
          ),
        );
        innerPos++;
      }
      outerPos++;
    }
    return childList;
  }

  Future<void> sendAnswer() async {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    List<FilterResult> finalSend = [];
    int outerPos = 0;
    int innerPos = 0;
    for (var result in widget.results) {
      List<VerifiableCredential> credList = [];
      for (var cred in result.credentials) {
        if (selectedCredsPerResult['o${outerPos}i$innerPos']!) {
          credList.add(cred);
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
    if (widget.isOidc) {
      var vp = await buildPresentation(finalSend, wallet.wallet, widget.nonce!,
          loadDocumentFunction: loadDocumentFast);
      var casted = VerifiablePresentation.fromJson(vp);
      logger.d(await verifyPresentation(vp, widget.nonce!,
          loadDocumentFunction: loadDocumentFast));
      logger.d(jsonDecode(vp));
      var res = await post(Uri.parse(widget.otherEndpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body:
              'presentation_submission=${casted.presentationSubmission!.toString()}&vp_token=$vp');

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
          type +=
              '''${c.type.firstWhere((element) => element != 'VerifiableCredential', orElse: () => '')},''';
        }
        type = type.substring(0, type.length - 1);

        await showModalBottomSheet(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
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
                      mainFontSize: 35,
                      centered: true),
                ),
              );
            });
        Navigator.of(context).pop();
      } else {
        for (var cred in casted.verifiableCredential!) {
          wallet.storeExchangeHistoryEntry(
              getHolderDidFromCredential(cred.toJson()),
              DateTime.now(),
              'present failed',
              widget.receiverDid);
        }

        await showModalBottomSheet(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline: AppLocalizations.of(navigatorKey.currentContext!)!
                      .presentationFailed,
                  success: false,
                  amount: const CurrencyDisplay(
                      amount: '', symbol: '', mainFontSize: 35, centered: true),
                ),
              );
            });
        Navigator.of(context).pop();
      }
    } else {
      var vp = await buildPresentation(finalSend, wallet.wallet,
          widget.message!.presentationDefinition.first.challenge);
      var presentationMessage = Presentation(
          replyUrl: '$relay/buffer/${widget.myDid}',
          returnRoute: ReturnRouteValue.thread,
          to: [widget.receiverDid],
          from: widget.myDid,
          verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
          threadId: widget.message!.threadId ?? widget.message!.id,
          parentThreadId: widget.message!.parentThreadId);
      sendMessage(widget.myDid, widget.otherEndpoint, wallet,
          presentationMessage, widget.receiverDid);
      for (var pres in presentationMessage.verifiablePresentation) {
        for (var cred in pres.verifiableCredential!) {
          wallet.storeExchangeHistoryEntry(
              getHolderDidFromCredential(cred.toJson()),
              DateTime.now(),
              'present',
              widget.receiverDid);
        }
      }
      Navigator.of(context).pop();
    }
    // Navigator.of(context).pop();
  }

  void reject() {
    Navigator.of(context).pop();
    //TODO: send Problem Report, if user rejects
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: AppLocalizations.of(navigatorKey.currentContext!)!.requestTitle,
      scanOnTap: () {},
      footerButtons: [
        TextButton(
            onPressed: reject,
            child: Text(
                AppLocalizations.of(navigatorKey.currentContext!)!.reject)),
        TextButton(
            onPressed: sendAnswer,
            child:
                Text(AppLocalizations.of(navigatorKey.currentContext!)!.send))
      ],
      child: SingleChildScrollView(
          child: Column(
        children: buildChilds(),
      )),
    );
  }
}
