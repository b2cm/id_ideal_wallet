import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:uuid/uuid.dart';

import '../views/offer_credential_dialog.dart';
import 'didcomm_message_handler.dart';

bool handleProposeCredential(ProposeCredential message, WalletProvider wallet) {
  throw Exception('We should never get such a message');
}

bool handleRequestCredential(RequestCredential message, WalletProvider wallet) {
  throw Exception('We should never get such a message');
}

Future<bool> handleOfferCredential(
    OfferCredential message, WalletProvider wallet) async {
  String threadId;
  logger.d('Offer Credential received');
  if (message.threadId != null) {
    threadId = message.threadId!;
  } else {
    threadId = message.id;
  }
  //Are there any previous messages?
  var entry = wallet.getConversation(threadId);
  var credential = message.detail!.first.credential;
  String myDid;

  //payment requested?
  String? toPay;
  String? invoice;
  if (message.attachments!.length > 1) {
    logger.d('with payment');
    var paymentReq = message.attachments!.firstWhere(
        (element) => element.format != null && element.format == 'lnInvoice');
    invoice = paymentReq.data.json!['lnInvoice'];
    var res = await get(
        Uri.https(
          'ln.pixeldev.eu',
          'lndhub/decodeinvoice',
          {'invoice': invoice},
        ),
        headers: {
          'Authorization': 'Bearer ${wallet.lnAuthToken}',
          'Content-Type': 'application/json'
        });

    if (res.statusCode == 200) {
      var decoded = jsonDecode(res.body);
      toPay = decoded['num_satoshis'];
    } else {
      throw Exception('cant decode invoice: ${res.body}');
    }
  }
  //No
  if (entry == null ||
      entry.protocol == DidcommProtocol.discoverFeature.value) {
    //show data to user
    var res = await showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) =>
            buildOfferCredentialDialog(context, credential, toPay));

    //pay the credential
    if (res) {
      if (invoice != null) {
        var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/payinvoice'),
            body: {'invoice': invoice},
            headers: {'Authorization': 'Bearer ${wallet.lnAuthToken}'});
        if (res.statusCode == 200) {
          logger.d('erfolgreich bezahlt');
          wallet.storePayment('-$toPay',
              'Credential Ausstellung: ${credential.type.firstWhere((element) => element != 'VerifiableCredential')}');
        } else {
          throw Exception('payment error: ${res.body}');
        }
      }
    } else {
      logger.d('user declined credential');
      // TODO: send problem report
      return false;
    }
  }

  if (entry == null) {
    myDid = await wallet.newConnectionDid();
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
      _sendProposeCredential(message, wallet, myDid);
      return false;
    }
    if (private == null) {
      _sendProposeCredential(message, wallet, myDid);
      return false;
    }
  } else {
    _sendProposeCredential(message, wallet, myDid);
    return false;
  }
  await _sendRequestCredential(message, wallet, myDid);
  return false;
}

_sendRequestCredential(
  OfferCredential offer,
  WalletProvider wallet,
  String myDid,
) async {
  var message = RequestCredential(
      detail: [
        LdProofVcDetail(
            credential: offer.detail!.first.credential,
            options: LdProofVcDetailOptions(
                proofType: offer.detail!.first.options.proofType,
                challenge: const Uuid().v4()))
      ],
      replyUrl: '$relay/buffer/$myDid',
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!]);
  sendMessage(myDid, determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

_sendProposeCredential(
  OfferCredential offer,
  WalletProvider wallet,
  String myDid,
) async {
  var credDid = await wallet.newCredentialDid();
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
      replyUrl: '$relay/buffer/$myDid',
      detail: [
        LdProofVcDetail(
            credential: newCred, options: offer.detail!.first.options)
      ]);

  //Sign attachment with credentialDid
  for (var a in message.attachments!) {
    await a.data.sign(wallet.wallet, credDid);
  }
  sendMessage(myDid, determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

Future<bool> handleIssueCredential(
    IssueCredential message, WalletProvider wallet) async {
  logger.d('Mir wurde ein Credential ausgestellt');
  var cred = message.credentials!.first;

  var entry = wallet.getConversation(message.threadId!);
  if (entry == null) {
    throw Exception(
        'Something went wrong. There could not be an issue message without request');
  }
  var previosMessage = DidcommPlaintextMessage.fromJson(entry.lastMessage);
  if (previosMessage.type == DidcommMessages.requestCredential.value) {
    var req = RequestCredential.fromJson(previosMessage.toJson());
    var challenge = req.detail!.first.options.challenge;
    var verified = await verifyCredential(cred, expectedChallenge: challenge);
    if (verified) {
      var credDid = getHolderDidFromCredential(cred.toJson());
      var storageCred = wallet.getCredential(credDid);
      if (storageCred != null) {
        wallet.storeCredential(cred.toString(), storageCred.hdPath);
        wallet.storeExchangeHistoryEntry(
            credDid, DateTime.now(), 'issue', message.from!);
        wallet.storeConversation(message, entry.myDid);
        var ack = EmptyMessage(
            ack: [message.id], threadId: message.threadId ?? message.id);
        sendMessage(
            entry.myDid,
            determineReplyUrl(message.replyUrl, message.replyTo),
            wallet,
            ack,
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
