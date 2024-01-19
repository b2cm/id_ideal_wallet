import 'dart:convert';

import 'package:crypto/crypto.dart';
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
    RequestPresentation message, WalletProvider wallet,
    [String? initialWebview]) async {
  logger.d('Request Presentation message received: $initialWebview');

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

  var definitionToHash = PresentationDefinition(
      inputDescriptors: definition.inputDescriptors
          .map((e) => InputDescriptor(
                id: '',
                constraints: InputDescriptorConstraints(
                  subjectIsIssuer: e.constraints?.subjectIsIssuer,
                  fields: e.constraints?.fields
                      ?.map((eIn) => InputDescriptorField(
                          path: eIn.path, id: '', filter: eIn.filter))
                      .toList(),
                ),
              ))
          .toList(),
      submissionRequirement: definition.submissionRequirement
          ?.map((e) => SubmissionRequirement(
              rule: e.rule,
              count: e.count,
              from: e.from,
              max: e.max,
              min: e.min))
          .toList(),
      id: '');
  var definitionHash = sha256.convert(utf8.encode(definitionToHash.toString()));
  logger.d(definitionHash);

  List<VerifiableCredential>? paymentCards;
  String? invoice;
  var paymentReq = message.attachments!.where(
      (element) => element.format != null && element.format == 'lnInvoice');
  if (paymentReq.isNotEmpty) {
    invoice = paymentReq.first.data.json?['lnInvoice'];
    logger.d('invoice: $invoice');
    if (invoice != null) {
      paymentCards = wallet.getSuitablePaymentCredentials(invoice);
      if (paymentCards.isEmpty) {
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.noPaymentMethod);
      }
    }
  }

  Map<String, dynamic>? invoiceReq;
  var lnInvoiceReq = message.attachments!.where((element) =>
      element.format != null && element.format == 'lnInvoiceRequest');
  if (lnInvoiceReq.isNotEmpty) {
    invoiceReq = lnInvoiceReq.first.data.json;
    logger.d('invoice request: $invoiceReq');
    if (invoiceReq != null) {
      paymentCards =
          wallet.getSuitablePaymentCredentialsForNetwork(invoiceReq['network']);
      if (paymentCards.isEmpty) {
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.noPaymentMethod);
      }
    }
  }

  try {
    var filtered =
        searchCredentialsForPresentationDefinition(creds, definition);
    logger.d('successfully filtered');

    var authorizedApps = wallet.getAuthorizedApps();
    logger.d(authorizedApps);

    var requester =
        determineReplyUrl(message.replyUrl, message.replyTo, myDid) ?? '';
    logger.d(requester);

    if (initialWebview != null && authorizedApps.contains(initialWebview)) {
      logger.d('send with no interaction');
      var vp = await buildPresentation(filtered, wallet.wallet,
          message.presentationDefinition.first.challenge,
          loadDocumentFunction: loadDocumentFast);
      var presentationMessage = Presentation(
          replyUrl: '$relay/buffer/$myDid',
          returnRoute: ReturnRouteValue.thread,
          to: [message.from!],
          from: myDid,
          verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
          threadId: message.threadId ?? message.id,
          parentThreadId: message.parentThreadId);

      sendMessage(myDid, requester, wallet, presentationMessage, message.from!,
          silent: true);
    } else {
      Navigator.of(navigatorKey.currentContext!).push(
        MaterialPageRoute(
          builder: (context) => PresentationRequestDialog(
            definitionHash: definitionHash.toString(),
            name: definition.name,
            purpose: definition.purpose,
            message: message,
            otherEndpoint: requester,
            receiverDid: message.from!,
            myDid: myDid,
            results: filtered,
            lnInvoice: invoice,
            paymentCards: paymentCards,
            lnInvoiceRequest: invoiceReq,
          ),
        ),
      );
    }
  } catch (e, stack) {
    logger.e(e, stackTrace: stack);
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
