import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:uuid/uuid.dart';

import '../constants/server_address.dart';
import '../provider/wallet_provider.dart';
import '../views/presentation_dialog.dart';
import '../views/presentation_proposal_dialog.dart';
import '../views/presentation_request.dart';
import 'didcomm_message_handler.dart';

Future<bool> handleProposePresentation(
    ProposePresentation message, WalletProvider wallet) async {
  var res = await showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => buildPresentationProposalDialog(
          context, message.presentationDefinition!.first));

  if (res) {
    //It should be the first message
    var myConnectionDid = await wallet.newConnectionDid();
    List<PresentationDefinitionWithOptions> withOptions = [];
    for (var definition in message.presentationDefinition!) {
      var tmp = PresentationDefinitionWithOptions(
          domain: 'domain',
          challenge: const Uuid().v4(),
          presentationDefinition: definition);
      withOptions.add(tmp);
    }
    var answer = RequestPresentation(
        presentationDefinition: withOptions,
        from: myConnectionDid,
        to: [message.from!],
        replyUrl: '$relay/buffer/$myConnectionDid');

    wallet.storeConversation(answer, myConnectionDid);

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
    RequestPresentation message, WalletProvider wallet) async {
  logger.d('Request Presentation message received');

  String threadId;
  if (message.threadId != null) {
    threadId = message.threadId!;
  } else {
    threadId = message.id;
  }
  //Are there any previous messages?
  var entry = wallet.getConversation(threadId);
  String myDid;
  if (entry == null) {
    myDid = await wallet.newConnectionDid();
  } else {
    myDid = entry.myDid;
  }

  var allCreds = wallet.allCredentials();
  List<VerifiableCredential> creds = [];
  allCreds.forEach((key, value) {
    if (value.w3cCredential != '') {
      var vc = VerifiableCredential.fromJson(value.w3cCredential);
      var type = getTypeToShow(vc.type);
      if (type != 'PaymentReceipt') {
        var id = getHolderDidFromCredential(vc.toJson());
        var status = wallet.revocationState[id];
        if (status == RevocationState.valid.index ||
            status == RevocationState.unknown.index) {
          creds.add(vc);
        }
      }
    }
  });
  var definition = message.presentationDefinition.first.presentationDefinition;
  logger.d(definition.toJson());

  try {
    var filtered =
        searchCredentialsForPresentationDefinition(creds, definition);
    logger.d('successfully filtered');
    Navigator.of(navigatorKey.currentContext!).push(
      MaterialPageRoute(
        builder: (context) => PresentationRequestDialog(
          name: definition.name,
          purpose: definition.purpose,
          message: message,
          otherEndpoint:
              determineReplyUrl(message.replyUrl, message.replyTo, myDid),
          receiverDid: message.from!,
          myDid: myDid,
          results: filtered,
        ),
      ),
    );
  } catch (e, stack) {
    logger.e(e, ['', stack]);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
  }
  return false;
}

Future<bool> handlePresentation(
    Presentation message, WalletProvider wallet) async {
  var conversation = wallet.getConversation(message.threadId ?? message.id);
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
        context: navigatorKey.currentContext!,
        builder: (context) =>
            buildPresentationDialog(message.verifiablePresentation, context));
    return false;
  } else {
    //TODO: show to user
    throw Exception('Presentation was wrong');
  }
}
