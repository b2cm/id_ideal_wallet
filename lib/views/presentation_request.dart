import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/x509.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/self_issuance.dart';
import 'package:provider/provider.dart';

import '../functions/didcomm_message_handler.dart';

class RequesterInfo extends StatefulWidget {
  final String requesterUrl;
  final String followingText;

  const RequesterInfo(
      {Key? key, required this.requesterUrl, required this.followingText})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => RequesterInfoState();
}

class RequesterInfoState extends State<RequesterInfo> {
  String info = AppLocalizations.of(navigatorKey.currentContext!)!.anonymous;
  bool isVerified = false;

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
      if (certInfo != null) {
        isVerified = true;
      }
      setState(() {});
    } catch (e) {
      logger.d('Problem bei Zertifikatsabfrage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 17,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(
              text: info,
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
                  isVerified ? Icons.check_circle : Icons.close,
                  size: 14,
                  color: isVerified
                      ? Colors.greenAccent.shade700
                      : Colors.redAccent.shade700,
                ),
              ),
            ),
            TextSpan(
                text: widget.followingText,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class PresentationRequestDialog extends StatefulWidget {
  final List<FilterResult> results;
  final String? name, purpose;
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
      this.name,
      this.purpose,
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
          if (res.submissionRequirement?.min != null &&
              innerPos <= res.submissionRequirement!.min!) {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
          } else {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
          }
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

    //overall name
    if (widget.name != null) {
      childList.add(
        Text(
          widget.name!,
          style: const TextStyle(
            fontSize: 26,
            color: Color(0xFF3b3b3b),
            fontWeight: FontWeight.bold,
          ),
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

    for (var result in widget.results) {
      bool all = false;

      var outerTileChildList = <Widget>[];

      // if (result.submissionRequirement != null) {
      //   childList.add(Text(AppLocalizations.of(navigatorKey.currentContext!)!
      //       .reasonForRequest));
      //   childList.add(Text(result.submissionRequirement?.purpose ??
      //       result.submissionRequirement?.name ??
      //       'Default'));
      //   childList.add(const SizedBox(
      //     height: 10,
      //   ));
      //
      //   if (result.submissionRequirement!.rule ==
      //       SubmissionRequirementRule.all) {
      //     all = true;
      //     childList
      //         .add(const Text('Wähle mindestens eins dieser Credentials aus'));
      //   } else {
      //     if (result.submissionRequirement!.count != null) {
      //       childList.add(Text(
      //           'Wähle ${result.submissionRequirement!.count!} Credential(s) aus'));
      //     } else if (result.submissionRequirement!.min != null) {
      //       childList.add(Text(
      //           'Wähle mindestens ${result.submissionRequirement!.min!} Credential(s) aus'));
      //     }
      //   }
      // }

      if (result.selfIssuable != null && result.selfIssuable!.isNotEmpty) {
        var pos = outerPos;
        for (var i in result.selfIssuable!) {
          childList.add(Text(AppLocalizations.of(navigatorKey.currentContext!)!
              .selfIssueAllowed));
          childList.add(ElevatedButton(
              onPressed: () async {
                var res = await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => CredentialSelfIssue(input: [i])));
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
      int credCount = 0;
      var selectedCredNames = <String>[];
      for (var v in result.credentials) {
        var key = 'o${outerPos}i$innerPos';
        if (selectedCredsPerResult[key]!) {
          credCount++;
          selectedCredNames.add(v.type
              .firstWhere((element) => element != 'VerifiableCredential'));
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
            title: Text(v.type
                .firstWhere((element) => element != 'VerifiableCredential')),
            children: buildCredSubject(v.credentialSubject),
          ),
        );
        innerPos++;
      }

      var outerTile = ExpansionTile(
        title: SizedBox(
          child: RichText(
            text: TextSpan(
                style: const TextStyle(
                  fontSize: 21,
                  color: Color(0xFF3b3b3b),
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                      text: '${credCount}x ',
                      style: TextStyle(
                        fontSize: 21,
                        color: Colors.greenAccent.shade700,
                        fontWeight: FontWeight.bold,
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
                style: const TextStyle(color: Colors.black),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SingleChildScrollView(
            child: Column(
              children: buildChilds(),
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        Column(
          children: [
            ElevatedButton(
                onPressed: reject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: Text(AppLocalizations.of(context)!.cancel)),
            const SizedBox(height: 5),
            ElevatedButton(
                onPressed: sendAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: Text(AppLocalizations.of(context)!.send)),
          ],
        )
      ],
    );
  }
}
