import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/util.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:provider/provider.dart';

import '../functions/didcomm_message_handler.dart';

class RequesterInfo extends StatefulWidget {
  final String requesterUrl;

  const RequesterInfo({Key? key, required this.requesterUrl}) : super(key: key);

  @override
  State<StatefulWidget> createState() => RequesterInfoState();
}

class RequesterInfoState extends State<RequesterInfo> {
  String info = 'anonym';

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
          'anonym';
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
  final RequestPresentation message;

  const PresentationRequestDialog(
      {Key? key,
      required this.results,
      required this.receiverDid,
      required this.myDid,
      required this.otherEndpoint,
      required this.message})
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
    childList.add(const Text('Die Daten werden übermittelt an:'));
    childList.add(RequesterInfo(requesterUrl: widget.otherEndpoint));
    childList.add(const SizedBox(
      height: 10,
    ));

    for (var result in widget.results) {
      bool all = false;
      if (result.submissionRequirement != null) {
        childList.add(const Text('Grund der Anfrage:'));
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
    var vp = await buildPresentation(finalSend, wallet.wallet,
        widget.message.presentationDefinition.first.challenge);
    var presentationMessage = Presentation(
        replyUrl: '$relay/buffer/${widget.myDid}',
        from: widget.myDid,
        verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
        threadId: widget.message.threadId ?? widget.message.id,
        parentThreadId: widget.message.parentThreadId);
    sendMessage(widget.myDid, widget.otherEndpoint, wallet, presentationMessage,
        widget.receiverDid);
    for (var pres in presentationMessage.verifiablePresentation) {
      for (var cred in pres.verifiableCredential) {
        wallet.storeExchangeHistoryEntry(
            getHolderDidFromCredential(cred.toJson()),
            DateTime.now(),
            'present',
            widget.receiverDid);
      }
    }
    Navigator.of(context).pop();
  }

  void reject() {
    Navigator.of(context).pop();
    //TODO: send Problem Report, if user rejects
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      child: SingleChildScrollView(
          child: Column(
        children: buildChilds(),
      )),
      title: 'Anfrage',
      scanOnTap: () {},
      footerButtons: [
        TextButton(onPressed: reject, child: const Text('Ablehnen')),
        TextButton(onPressed: sendAnswer, child: const Text('Senden'))
      ],
    );
  }
}
