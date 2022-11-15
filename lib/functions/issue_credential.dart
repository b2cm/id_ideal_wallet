import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:uuid/uuid.dart';

import '../constants/server_address.dart';
import '../provider/wallet_provider.dart';
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
  String myDid;

  //payment requested?
  String? toPay;
  String? invoice;
  if (message.attachments!.length > 1) {
    logger.d('with payment');
    var paymentReq = message.attachments!.where(
        (element) => element.format != null && element.format == 'lnInvoice');
    if (paymentReq.isNotEmpty) {
      invoice = paymentReq.first.data.json!['lnInvoice'];
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
  }
  Map<String, String> paymentDetails = {};
  //No
  if (entry == null ||
      entry.protocol == DidcommProtocol.discoverFeature.value) {
    //show data to user
    var res = await showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) =>
            buildOfferCredentialDialog(context, message.detail!, toPay));

    //pay the credential

    if (res) {
      if (invoice != null) {
        var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/payinvoice'),
            body: {'invoice': invoice},
            headers: {'Authorization': 'Bearer ${wallet.lnAuthToken}'});
        if (res.statusCode == 200) {
          logger.d('erfolgreich bezahlt');
          paymentDetails['value'] = '-$toPay';
          paymentDetails['note'] =
              '${message.detail!.first.credential.type.firstWhere((element) => element != 'VerifiableCredential')} empfangen';

          showModalBottomSheet(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              context: navigatorKey.currentContext!,
              builder: (context) {
                return PaymentFinished(
                    headline: "Zahlung erfolgreich",
                    success: true,
                    amount: CurrencyDisplay(
                        amount: "-$toPay",
                        symbol: '€',
                        mainFontSize: 35,
                        centered: true));
              });
        } else {
          showModalBottomSheet(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              context: navigatorKey.currentContext!,
              builder: (context) {
                return PaymentFinished(
                  headline: "Zahlung fehlgeschlagen",
                  success: false,
                  amount: CurrencyDisplay(
                      amount: "-$toPay",
                      symbol: '€',
                      mainFontSize: 35,
                      centered: true),
                  additionalInfo: Column(children: const [
                    SizedBox(height: 20),
                    Text("Zahlung konnte nicht durchgeführt werden",
                        style: TextStyle(color: Colors.red)),
                  ]),
                );
              });
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
  for (var credDetail in message.detail!) {
    var subject = credDetail.credential.credentialSubject;
    if (subject.containsKey('id')) {
      String id = subject['id'];
      String? private;
      try {
        private = await wallet.getPrivateKeyForCredentialDid(id);
      } catch (e) {
        _sendProposeCredential(message, wallet, myDid, paymentDetails);
        return false;
      }
      if (private == null) {
        _sendProposeCredential(message, wallet, myDid, paymentDetails);
        return false;
      }
    } else {
      _sendProposeCredential(message, wallet, myDid, paymentDetails);
      return false;
    }
  }
  await _sendRequestCredential(message, wallet, myDid);
  return false;
}

_sendRequestCredential(
  OfferCredential offer,
  WalletProvider wallet,
  String myDid,
) async {
  List<LdProofVcDetail> detail = [];
  for (var d in offer.detail!) {
    detail.add(LdProofVcDetail(
        credential: d.credential,
        options: LdProofVcDetailOptions(
            proofType: d.options.proofType, challenge: const Uuid().v4())));
  }
  var message = RequestCredential(
      detail: detail,
      replyUrl: '$relay/buffer/$myDid',
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!]);
  sendMessage(myDid, determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

_sendProposeCredential(OfferCredential offer, WalletProvider wallet,
    String myDid, Map<String, String> paymentDetails) async {
  List<LdProofVcDetail> detail = [];
  var firstDid = '';
  for (int i = 0; i < offer.detail!.length; i++) {
    var credDid = await wallet.newCredentialDid();
    if (i == 0) {
      firstDid = credDid;
    }
    var offeredCred = offer.detail![i].credential;
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
    detail.add(LdProofVcDetail(
        credential: newCred, options: offer.detail!.first.options));
  }
  var message = ProposeCredential(
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!],
      replyUrl: '$relay/buffer/$myDid',
      detail: detail);

  //Sign attachment with credentialDid
  for (var a in message.attachments!) {
    await a.data.sign(wallet.wallet, firstDid);
  }

  if (paymentDetails.isNotEmpty) {
    wallet.storePayment(
        paymentDetails['value']!, paymentDetails['note']!, [firstDid]);
  }

  sendMessage(myDid, determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

Future<bool> handleIssueCredential(
    IssueCredential message, WalletProvider wallet) async {
  logger.d('Mir wurden Credentials ausgestellt');

  var entry = wallet.getConversation(message.threadId!);
  if (entry == null) {
    throw Exception(
        'Something went wrong. There could not be an issue message without request');
  }

  var previosMessage = DidcommPlaintextMessage.fromJson(entry.lastMessage);
  if (previosMessage.type == DidcommMessages.requestCredential.value) {
    for (int i = 0; i < message.credentials!.length; i++) {
      var req = RequestCredential.fromJson(previosMessage.toJson());
      var cred = message.credentials![i];
      var challenge = req.detail![i].options.challenge;
      var verified = await verifyCredential(cred, expectedChallenge: challenge);
      if (verified) {
        var credDid = getHolderDidFromCredential(cred.toJson());
        var storageCred = wallet.getCredential(credDid);
        if (storageCred == null) {
          throw Exception(
              'No hd path for credential found. Sure we control it?');
        }

        var type = cred.type
            .firstWhere((element) => element != 'VerifiableCredential');

        if (type == 'PaymentReceipt') {
          wallet.storeCredential(cred.toString(), storageCred.hdPath,
              cred.credentialSubject['receiptId']);
        } else {
          wallet.storeCredential(cred.toString(), storageCred.hdPath);
          wallet.storeExchangeHistoryEntry(
              credDid, DateTime.now(), 'issue', message.from!);
        }
      } else {
        throw Exception('Credential signature is wrong');
      }

      wallet.storeConversation(message, entry.myDid);
      var ack = EmptyMessage(
          ack: [message.id], threadId: message.threadId ?? message.id);
      sendMessage(
          entry.myDid,
          determineReplyUrl(message.replyUrl, message.replyTo),
          wallet,
          ack,
          message.from!);
    }
  } else {
    throw Exception(
        'Issue credential could only follow to request credential message');
  }
  return false;
}
