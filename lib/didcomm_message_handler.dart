import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:uuid/uuid.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

String myService = 'xmpp:testuser@localhost';

Future<bool> handleDidcommMessage(WalletStore wallet, String message,
    BuildContext context, MessageHandler xmppHandler) async {
  var plaintext = await getPlaintext(message, wallet);
  if (plaintext.attachments != null && plaintext.attachments!.isNotEmpty) {
    for (var a in plaintext.attachments!) {
      try {
        await a.data.resolveData();
      } catch (e) {
        print(e);
      }
    }
  }
  switch (plaintext.type) {
    case 'https://didcomm.org/issue-credential/3.0/propose-credential':
      return _handleProposeCredential(
          ProposeCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/offer-credential':
      return _handleOfferCredential(
          OfferCredential.fromJson(plaintext.toJson()),
          wallet,
          context,
          xmppHandler);

    case 'https://didcomm.org/issue-credential/3.0/request-credential':
      return _handleRequestCredential(
          RequestCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/issue-credential':
      return _handleIssueCredential(
          IssueCredential.fromJson(plaintext.toJson()),
          wallet,
          xmppHandler,
          context);

    case 'https://didcomm.org/present-proof/3.0/propose-presentation':
      return _handleProposePresentation(
          ProposePresentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/present-proof/3.0/request-presentation':
      return _handleRequestPresentation(
          RequestPresentation.fromJson(plaintext.toJson()),
          wallet,
          context,
          xmppHandler);

    case 'https://didcomm.org/present-proof/3.0/presentation':
      return _handlePresentation(
          Presentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/report-problem/2.0/problem-report':
      return _handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);
    default:
      throw Exception('Unsupported message type');
  }
}

Future<DidcommPlaintextMessage> getPlaintext(
    String message, WalletStore wallet) async {
  try {
    var uri = Uri.parse(message);
    print('oob');
    if (uri.queryParameters.containsKey('_oob')) {
      var oob = oobMessageFromUrl(message);
      //For now we expect one message here
      if (oob.attachments!.isNotEmpty) {
        for (var a in oob.attachments!) {
          print(a.data.links);
          await a.data.resolveData();
        }
        try {
          var plain = DidcommPlaintextMessage.fromJson(
              oob.attachments!.first.data.json!);
          plain.from ??= oob.from;
          return plain;
        } catch (e) {
          print('No oob: $e');
          throw Exception('OOB Message with no proper attachment');
        }
      }
    }
  } catch (e) {
    try {
      print('No oob: $e');
      var encrypted = DidcommEncryptedMessage.fromJson(message);
      print('is encrypted');
      var decrypted = await encrypted.decrypt(wallet);
      if (decrypted is DidcommPlaintextMessage) {
        decrypted.from ??= encrypted.protectedHeaderSkid!.split('#').first;
        List<String> toDids = [];
        for (var entry in encrypted.recipients) {
          String kid = entry['header']['kid']!;
          var did = kid.split('#').first;
          if (!toDids.contains(did)) toDids.add(did);
        }
        decrypted.to = toDids;
        return decrypted;
      } else {
        return getPlaintext(decrypted.toString(), wallet);
      }
    } catch (e) {
      print('No encrypted: $e');
      try {
        var signed = DidcommSignedMessage.fromJson(message);
        if (signed.payload is DidcommPlaintextMessage) {
          return signed.payload as DidcommPlaintextMessage;
        } else {
          return getPlaintext(signed.payload.toString(), wallet);
        }
      } catch (e) {
        print('Nothig: $e');
        throw Exception(
            'Unexpected message format - only expect Signed or encrypted messages');
      }
    }
  }

  throw Exception(
      'Unexpected message format - only expect Signed or encrypted messages');
}

_handleProposeCredential(ProposeCredential message, WalletStore wallet) {
  throw Exception('We should never get such a message');
}

Future<bool> _handleOfferCredential(OfferCredential message, WalletStore wallet,
    BuildContext context, MessageHandler xmppHandler) async {
  String threadId;
  print('Offer Credential received');
  if (message.threadId != null) {
    threadId = message.threadId!;
  } else {
    threadId = message.id;
  }
  //Are there any previous messages?
  var entry = wallet.getConversationEntry(threadId);
  var credential = message.detail!.first.credential;
  String myDid;
  //No
  if (entry == null) {
    //show data to user
    var res = await showDialog(
        context: context,
        builder: (BuildContext context) =>
            _buildOfferCredentialDialog(context, credential));
    myDid = await wallet.getNextConnectionDID(KeyType.x25519);
    print(res);
  } else {
    myDid = entry.myDid;
  }

  //check, if we control did
  Map<String, dynamic> subject = credential.credentialSubject;
  if (subject.containsKey('id')) {
    String id = subject['id'];
    String? private;
    try {
      private = await wallet.getPrivateKeyForCredentialDid(id);
    } catch (e) {
      _sendProposeCredential(message, wallet, myDid, xmppHandler);
      return false;
    }
    if (private == null) {
      _sendProposeCredential(message, wallet, myDid, xmppHandler);
      return false;
    }
  } else {
    _sendProposeCredential(message, wallet, myDid, xmppHandler);
    return false;
  }
  await _sendRequestCredential(message, wallet, myDid, xmppHandler);
  return false;
}

_sendRequestCredential(OfferCredential offer, WalletStore wallet, String myDid,
    MessageHandler xmppHandler) async {
  var message = RequestCredential(
      detail: [
        LdProofVcDetail(
            credential: offer.detail!.first.credential,
            options: LdProofVcDetailOptions(
                proofType: offer.detail!.first.options.proofType,
                challenge: const Uuid().v4()))
      ],
      replyUrl: myService,
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!]);
  _sendMessage(
      myDid, offer.replyUrl!, wallet, xmppHandler, message, offer.from!);
}

_sendProposeCredential(OfferCredential offer, WalletStore wallet, String myDid,
    MessageHandler xmppHandler) async {
  var credDid = await wallet.getNextCredentialDID(KeyType.ed25519);
  print('Meine credential did: $credDid');
  var offeredCred = offer.detail!.first.credential;
  var credSubject = offeredCred.credentialSubject;
  credSubject['id'] = credDid;
  var newCred = VerifiableCredential(
      id: credDid,
      context: offeredCred.context,
      type: offeredCred.type,
      issuer: offeredCred.issuer,
      credentialSubject: credSubject,
      issuanceDate: offeredCred.issuanceDate,
      credentialSchema: offeredCred.credentialSchema,
      expirationDate: offeredCred.expirationDate);

  var message = ProposeCredential(
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!],
      replyUrl: myService,
      detail: [
        LdProofVcDetail(
            credential: newCred, options: offer.detail!.first.options)
      ]);

  //Sign attachment with credentialDid
  for (var a in message.attachments!) {
    await a.data.sign(wallet, credDid);
  }
  _sendMessage(
      myDid, offer.replyUrl!, wallet, xmppHandler, message, offer.from!);
}

_sendMessage(
    String myDid,
    String otherEndpoint,
    WalletStore wallet,
    MessageHandler xmppHandler,
    DidcommPlaintextMessage message,
    String receiverDid) async {
  var myPrivateKey = await wallet.getPrivateKeyForConnectionDidAsJwk(myDid);
  print(receiverDid);
  var recipientDDO = (await resolveDidDocument(receiverDid))
      .resolveKeyIds()
      .convertAllKeysToJwk();
  if (message.type != 'https://didcomm.org/reserved/2.0/empty') {
    await wallet.storeConversationEntry(message, myDid);
  }
  var encrypted = DidcommEncryptedMessage.fromPlaintext(
      senderPrivateKeyJwk: myPrivateKey!,
      recipientPublicKeyJwk: [
        (recipientDDO.keyAgreement!.first as VerificationMethod).publicKeyJwk!
      ],
      plaintext: message);

  if (otherEndpoint.startsWith('xmpp')) {
    print(otherEndpoint.split(':').last);
    xmppHandler.sendMessage(
        Jid.fromFullJid(otherEndpoint.split(':').last), encrypted.toString());
  } else {
    throw Exception('We do not support other transports');
  }
}

Widget _buildOfferCredentialDialog(
    BuildContext context, VerifiableCredential credential) {
  List<Widget> contentData = [];
  contentData.add(Text(credential.type.last,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
  contentData.add(const SizedBox(
    height: 10,
  ));
  var subject = buildCredSubject(credential.credentialSubject);
  contentData += subject;
  return AlertDialog(
    title: const Text('Ihnen wird ein Credential angeboten'),
    content: Card(
        child: Column(
      children: contentData,
    )),
    actions: [
      TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen')),
      TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ok'))
    ],
  );
}

bool _handleRequestCredential(RequestCredential message, WalletStore wallet) {
  return false;
}

Future<bool> _handleIssueCredential(IssueCredential message, WalletStore wallet,
    MessageHandler xmppHandler, BuildContext context) async {
  print('Mir wurde ein Credential ausgesetllt');
  var cred = message.credentials!.first;

  var entry = wallet.getConversationEntry(message.threadId!);
  if (entry == null) {
    throw Exception(
        'Somthing went wrong. There could not be an issue message without request');
  }
  var previosMessage = DidcommPlaintextMessage.fromJson(entry.lastMessage);
  print(previosMessage.type);
  if (previosMessage.type ==
      'https://didcomm.org/issue-credential/3.0/request-credential') {
    var req = RequestCredential.fromJson(previosMessage.toJson());
    var challenge = req.detail!.first.options.challenge;
    var verified = await verifyCredential(cred, expectedChallenge: challenge);
    print(verified);
    if (verified) {
      var credDid = getHolderDidFromCredential(cred.toJson());
      print('Holder of credential: $credDid');
      var storageCred = wallet.getCredential(credDid);
      if (storageCred != null) {
        await wallet.storeCredential(cred.toString(), '', storageCred.hdPath);
        await wallet.storeConversationEntry(message, entry.myDid);
        var ack = EmptyMessage(ack: [message.id]);
        _sendMessage(entry.myDid, message.replyUrl!, wallet, xmppHandler, ack,
            message.from!);
        return true;
      } else {
        throw Exception('No hd path for credential found. Sure we control it?');
      }
    } else {
      throw Exception('Credential signature is wrong');
    }
  } else {
    throw Exception(
        'Issue credential could only follow to request credential message');
  }
}

bool _handleProposePresentation(
    ProposePresentation message, WalletStore wallet) {
  return false;
}

Future<bool> _handleRequestPresentation(
    RequestPresentation message,
    WalletStore wallet,
    BuildContext context,
    MessageHandler xmppHandler) async {
  print('Request Presentation message received');

  String threadId;
  if (message.threadId != null) {
    threadId = message.threadId!;
  } else {
    threadId = message.id;
  }
  print(threadId);
  //Are there any previous messages?
  var entry = wallet.getConversationEntry(threadId);
  String myDid;
  if (entry == null) {
    myDid = await wallet.getNextConnectionDID(KeyType.x25519);
  } else {
    myDid = entry.myDid;
  }

  var allCreds = wallet.getAllCredentials();
  List<Map<String, dynamic>> creds = [];
  allCreds.forEach((key, value) {
    if (value.w3cCredential != '') creds.add(jsonDecode(value.w3cCredential));
  });
  var definition = message.presentationDefinition.first.presentationDefinition;

  var filtered = searchCredentialsForPresentationDefinition(creds, definition);
  print(filtered.length);
  print(filtered.first.credentials.length);
  if (filtered.isNotEmpty) {
    List<FilterResult> finalShow = [];
    //filter List of credentials -> check for duplicates by type
    for (var result in filtered) {
      List<VerifiableCredential> filteredCreds = [];
      for (var cred in result.credentials) {
        if (filteredCreds.isEmpty) {
          filteredCreds.add(cred);
        } else {
          bool typeFound = false;
          for (var cred2 in filteredCreds) {
            if (cred.isOfSameType(cred2)) {
              typeFound = true;
              break;
            }
          }
          if (!typeFound) filteredCreds.add(cred);
        }
      }
      finalShow.add(FilterResult(
          credentials: filteredCreds,
          presentationDefinitionId: definition.id,
          matchingDescriptorIds: result.matchingDescriptorIds,
          submissionRequirement: result.submissionRequirement));
    }

    print(finalShow);
    // var res = await showDialog(
    //     context: context,
    //     builder: (BuildContext context) => StatefulBuilder(
    //         builder: (context, setState) =>
    //             _showRequestedCreds(finalShow, context)));

    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => PresentationRequestDialog(
              xmppHandler: xmppHandler,
              wallet: wallet,
              message: message,
              otherEndpoint: message.replyUrl!,
              receiverDid: message.from!,
              myDid: myDid,
              results: finalShow,
            )));

    //   var vp = await buildPresentation(
    //       finalShow, wallet, message.presentationDefinition.first.challenge);
    //   var presentationMessage = Presentation(
    //       verifiablePresentation: [VerifiablePresentation.fromJson(vp)]);
    //   _sendMessage(myDid, message.replyUrl!, wallet, xmppHandler,
    //       presentationMessage, message.from!);
    // }
  }
  return false;
}

// Widget _showRequestedCreds(List<FilterResult> results, BuildContext context) {
//   return AlertDialog(
//     title: Text('Folgende Credentials wurden angefragt:'),
//     content: PresentationRequestDialog(results: results),
//     actions: [
//       TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//           },
//           child: const Text('Abbrechen')),
//       TextButton(
//           onPressed: () {
//             Navigator.of(context).pop();
//           },
//           child: const Text('Ok'))
//     ],
//   );
// }

bool _handlePresentation(Presentation message, WalletStore wallet) {
  return false;
}

bool _handleProblemReport(ProblemReport message, WalletStore wallet) {
  return false;
}

class PresentationRequestDialog extends StatefulWidget {
  List<FilterResult> results;
  String myDid;
  String otherEndpoint;
  WalletStore wallet;
  MessageHandler xmppHandler;
  String receiverDid;
  RequestPresentation message;
  PresentationRequestDialog(
      {Key? key,
      required this.results,
      required this.xmppHandler,
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
            title: Text(v.type.last),
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
        threadId: widget.message.threadId ?? widget.message.id);
    _sendMessage(widget.myDid, widget.otherEndpoint, widget.wallet,
        widget.xmppHandler, presentationMessage, widget.receiverDid);
    Navigator.of(context).pop();
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
        TextButton(onPressed: sendAnswer, child: const Text('Senden'))
      ],
    );
  }
}
