import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';

import '../functions/didcomm_message_handler.dart';
import '../main.dart';

class PresentationRequestDialog extends StatefulWidget {
  final List<FilterResult> results;
  final String myDid;
  final String otherEndpoint;
  final WalletStore wallet;
  final String receiverDid;
  final RequestPresentation message;

  const PresentationRequestDialog(
      {Key? key,
      required this.results,
      required this.wallet,
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
        selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        innerPos++;
      }
      outerPos++;
    }
    print(selectedCredsPerResult);
  }

  List<Widget> buildChilds() {
    List<Widget> childList = [];
    int outerPos = 0;
    int innerPos = 0;

    for (var result in widget.results) {
      bool all = false;
      if (result.submissionRequirement != null) {
        childList.add(Text(result.submissionRequirement!.name ?? 'Default'));
        if (result.submissionRequirement!.rule ==
            SubmissionRequirementRule.all) {
          all = true;
          childList.add(const Text('Diese Credentials werden alle benötigt'));
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
        print('out: ${selectedCredsPerResult[key]}');
        childList.add(
          ExpansionTile(
            leading: Checkbox(
                onChanged: (bool? newValue) {
                  print('change');
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = all ? true : newValue;
                    }
                    print(selectedCredsPerResult[key]);
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
    List<FilterResult> finalSend = [];
    int outerPos = 0;
    int innerPos = 0;
    print(selectedCredsPerResult);
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
    var vp = await buildPresentation(finalSend, widget.wallet,
        widget.message.presentationDefinition.first.challenge);
    var presentationMessage = Presentation(
        verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
        threadId: widget.message.threadId ?? widget.message.id,
        parentThreadId: widget.message.parentThreadId);
    sendMessage(widget.myDid, widget.otherEndpoint, widget.wallet,
        presentationMessage, widget.receiverDid);
    for (var pres in presentationMessage.verifiablePresentation) {
      for (var cred in pres.verifiableCredential) {
        await widget.wallet.storeExchangeHistoryEntry(
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
    return Scaffold(
      appBar: AppBar(
          title: const Text('Presentation Request'),
          automaticallyImplyLeading: false),
      body: Column(
        children: buildChilds(),
      ),
      persistentFooterButtons: [
        TextButton(onPressed: reject, child: const Text('Ablehnen')),
        TextButton(onPressed: sendAnswer, child: const Text('Senden'))
      ],
    );
  }
}
