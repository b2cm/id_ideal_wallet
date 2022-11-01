import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/views/presentation_dialog.dart';
import 'package:id_ideal_wallet/views/presentation_proposal_dialog.dart';
import 'package:uuid/uuid.dart';

import '../views/presentation_request.dart';
import 'didcomm_message_handler.dart';

Future<bool> handleProposePresentation(ProposePresentation message,
    WalletStore wallet, BuildContext context) async {
  var res = await showDialog(
      context: context,
      builder: (BuildContext context) => buildPresentationProposalDialog(
          context, message.presentationDefinition!.first));

  if (res) {
    //It should be the first message
    var myConnectionDid = await wallet.getNextConnectionDID(KeyType.x25519);
    List<PresentationDefinitionWithOptions> withOptions = [];
    for (var definition in message.presentationDefinition!) {
      var tmp = PresentationDefinitionWithOptions(
          domain: 'domain',
          challenge: Uuid().v4(),
          presentationDefinition: definition);
      withOptions.add(tmp);
    }
    var answer = RequestPresentation(
        presentationDefinition: withOptions,
        from: myConnectionDid,
        to: [message.from!],
        replyUrl: '$relay/buffer/$myConnectionDid');

    await wallet.storeConversationEntry(answer, myConnectionDid);

    sendMessage(
        myConnectionDid,
        determineReplyUrl(message.replyUrl, message.replyTo),
        wallet,
        answer,
        message.from!);
  }
  return false;
}

Future<bool> handleRequestPresentation(
  RequestPresentation message,
  WalletStore wallet,
  BuildContext context,
) async {
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

  try {
    var filtered =
        searchCredentialsForPresentationDefinition(creds, definition);
    print(filtered.length);
    print(filtered.first.credentials.length);
    if (filtered.isNotEmpty && filtered.first.credentials.isNotEmpty) {
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

      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PresentationRequestDialog(
                wallet: wallet,
                message: message,
                otherEndpoint:
                    determineReplyUrl(message.replyUrl, message.replyTo),
                receiverDid: message.from!,
                myDid: myDid,
                results: finalShow,
              )));
    } else {
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Keine Credentials gefunden'),
                content: const Text(
                    'Sie besitzen keine Credential, die der Anfrage entsprechen'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Ok'))
                ],
              ));
    }
  } catch (e) {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Keine Credentials gefunden'),
              content: Text(
                  'Sie besitzen keine Credential, die der Anfrage entsprechen ($e)'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Ok'))
              ],
            ));
  }
  return false;
}

Future<bool> handlePresentation(
    Presentation message, WalletStore wallet, BuildContext context) async {
  var conversation =
      wallet.getConversationEntry(message.threadId ?? message.id);
  if (conversation == null) {
    //TODO: send Problem Report
    throw Exception('We have not requested a presentation');
  }
  var requestPresentation =
      RequestPresentation.fromJson(conversation.lastMessage);
  var challenge = requestPresentation.presentationDefinition.first.challenge;

  var verified =
      await verifyPresentation(message.verifiablePresentation.first, challenge);
  if (verified) {
    await showDialog(
        context: context,
        builder: (context) =>
            buildPresentationDialog(message.verifiablePresentation, context));
    return false;
  } else {
    //TODO: show to user
    throw Exception('Presentation was wrong');
  }
}
