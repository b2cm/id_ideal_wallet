import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';

import '../views/presentation_request.dart';
import 'didcomm_message_handler.dart';

bool handleProposePresentation(
    ProposePresentation message, WalletStore wallet) {
  throw Exception('We should never get such a message');
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
  }
  return false;
}

bool handlePresentation(Presentation message, WalletStore wallet) {
  throw Exception('We should never get such a message');
}
