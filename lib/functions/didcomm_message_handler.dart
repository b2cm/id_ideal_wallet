import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/discover_feature.dart';
import 'package:id_ideal_wallet/functions/issue_credential.dart';
import 'package:id_ideal_wallet/functions/present_proof.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

Future<bool> handleOobUrl(String url) async {
  var asUri = Uri.parse(url);
  var oobUrl = asUri.queryParameters['_ooburl'];
  if (oobUrl != null) {
    var messageGot = await get(Uri.parse(oobUrl));
    logger.d(messageGot.body);
    return handleDidcommMessage(messageGot.body);
  }
  return false;
}

Future<bool> handleOobId(String url) async {
  try {
    var asUri = Uri.parse(url);
    var messageResponse = await get(asUri);
    logger.d(messageResponse.body);

    Map json = jsonDecode(messageResponse.body);
    if (json.containsKey('value')) {
      return handleDidcommMessage(json['value'],
          asUri.removeFragment().replace(queryParameters: {}).toString());
    }
    logger.d(asUri.removeFragment().replace(queryParameters: {}).toString());
    return handleDidcommMessage(messageResponse.body,
        asUri.removeFragment().replace(queryParameters: {}).toString());
  } catch (e) {
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!
            .downloadFailedExplanation);
    logger.d(e);
    return false;
  }
}

Future<bool> handleDidcommMessage(String message, [String? replyUrl]) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);
  while (!wallet.isOpen()) {
    await Future.delayed(const Duration(seconds: 1));
  }

  var plaintext = await getPlaintext(message, wallet);
  if (plaintext.attachments != null && plaintext.attachments!.isNotEmpty) {
    for (var a in plaintext.attachments!) {
      try {
        await a.data.resolveData();
      } catch (e) {
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .downloadFailedExplanation);
        logger.e(e);
      }
    }
  }
  switch (plaintext.type) {
    case DidcommMessages.invitation:
      return handleInvitation(
          OutOfBandMessage.fromJson(plaintext.toJson()), wallet, replyUrl);

    case DidcommMessages.proposeCredential:
      return handleProposeCredential(
          ProposeCredential.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.offerCredential:
      return handleOfferCredential(
          OfferCredential.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.requestCredential:
      return handleRequestCredential(
          RequestCredential.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.issueCredential:
      return handleIssueCredential(
          IssueCredential.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.proposePresentation:
      return handleProposePresentation(
          ProposePresentation.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.requestPresentation:
      return handleRequestPresentation(
          RequestPresentation.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.presentation:
      return handlePresentation(
          Presentation.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.problemReport:
      return handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.issueCredentialProblem:
      return handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.requestPresentationProblem:
      return handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.discoverFeatureQuery:
      return handleDiscoverFeatureQuery(
          QueryMessage.fromJson(plaintext.toJson()), wallet);

    case DidcommMessages.emptyMessage:
      return handleEmptyMessage(plaintext, wallet);

    default:
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.unexpectedMessage,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .unknownMessageExplanation);
      throw Exception('Unsupported message type');
  }
}

Future<bool> handleEmptyMessage(
    DidcommPlaintextMessage message, WalletProvider wallet) async {
  logger.d('got empty message');
  if (message.to != null && message.to!.isNotEmpty) {
    for (var d in message.to!) {
      wallet.removeRelayedDid(d);
    }
  }
  return true;
}

bool isUri(String mayBeUri) {
  try {
    Uri.parse(mayBeUri);
    return true;
  } catch (e) {
    return false;
  }
}

Future<DidcommPlaintextMessage> getPlaintext(
    String message, WalletProvider wallet) async {
  logger.d(message);

  if (isUri(message) && message.contains('_oob')) {
    var uri = Uri.parse(message);
    if (uri.queryParameters.containsKey('_oob')) {
      var oob = oobMessageFromUrl(message);
      //For now we expect one message here
      if (oob.attachments != null && oob.attachments!.isNotEmpty) {
        for (var a in oob.attachments!) {
          if (a.data.json == null) {
            try {
              await a.data.resolveData();
            } catch (e) {
              logger.e(e);
            }
          }
        }
        try {
          dynamic jsonData = oob.attachments!.first.data.json!;
          var plain = DidcommPlaintextMessage.fromJson(
              jsonData is List ? jsonData.first : jsonData);
          plain.from ??= oob.from;
          return plain;
        } catch (e) {
          logger.e(e);
          throw Exception('OOB Message with no proper attachment: $e');
        }
      } else {
        return oob;
      }
    }
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.unexpectedMessage,
        AppLocalizations.of(navigatorKey.currentContext!)!
            .malformedOOBExplanation);
    throw Exception('No proper oob message');
  } else if (isEncryptedMessage(message)) {
    try {
      var encrypted = DidcommEncryptedMessage.fromJson(message);
      var decrypted =
          await encrypted.decrypt(wallet.wallet, didResolver: resolveKeri);
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
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.malformedMessage,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .malformedEncryptedMessage);
      throw Exception('Decryption Error: $e');
    }
  } else if (isSignedMessage(message)) {
    var signed = DidcommSignedMessage.fromJson(message);
    if (signed.payload is DidcommPlaintextMessage) {
      return signed.payload as DidcommPlaintextMessage;
    } else {
      return getPlaintext(signed.payload.toString(), wallet);
    }
  } else if (isPlaintextMessage(message)) {
    var plain = DidcommPlaintextMessage.fromJson(message);
    return plain;
  } else {
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.unexpectedMessage,
        AppLocalizations.of(navigatorKey.currentContext!)!
            .malformedOOBExplanation);
    throw Exception('unsupported message');
  }
}

Future<DidDocument> resolveKeri(String did) {
  logger.d(did);
  if (did.startsWith('did:keri')) {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var ddo = wallet.getConfig(did);
    logger.d(ddo);
    if (ddo != null) {
      return Future.value(DidDocument.fromJson(ddo));
    } else {
      throw Exception('no ddo');
    }
  } else {
    return resolveDidDocument(did);
  }
}

Future<bool> handleInvitation(
    OutOfBandMessage invitation, WalletProvider wallet,
    [String? replyUrl]) async {
  if (invitation.accept != null &&
      !invitation.accept!.contains(DidcommProfiles.v2)) {
    //better: send problem report
    throw Exception('counterpart do not speak didcommv2');
  }
  var acceptedGoalCodesPresent = ['streamlined-vp', 'de.kaprion.ppp.s2p'];
  var acceptedGoalCodesIssue = ['streamlined-vc', 'de.kaprion.icp.s2p'];
  if (invitation.goalCode != null &&
      acceptedGoalCodesPresent.contains(invitation.goalCode)) {
    // counterpart wants to ask for presentation
    logger.d('Presentation requested');
    var threadId = const Uuid().v4();
    String myDid;
    if (invitation.from!.startsWith('did:keri') ||
        invitation.from!.startsWith('did:key:z82')) {
      myDid = await wallet.newConnectionDid(KeyType.p384);
    } else {
      myDid = await wallet.newConnectionDid();
    }

    if (replyUrl != null) {
      var con = wallet.getConnection(myDid);
      wallet.wallet.storeConnection(replyUrl, 'Kaprion', con!.hdPath,
          keyType: KeyType.p384);
    }

    logger.d(replyUrl);
    var propose = ProposePresentation(
        id: threadId,
        threadId: threadId,
        parentThreadId: invitation.id,
        from: myDid,
        to: [invitation.from!],
        replyUrl: '$relay/buffer/$myDid');
    wallet.storeConversation(propose, myDid);

    sendMessage(
        myDid,
        replyUrl ?? determineReplyUrl(invitation.replyUrl, invitation.replyTo),
        wallet,
        propose,
        invitation.from!);
    return true;
  } else if (invitation.goalCode != null &&
      invitation.goalCode == 'de.kaprion.icp.s2p') {
    // counterpart like to issue credential
    var threadId = const Uuid().v4();
    var myDid = await wallet.newConnectionDid(KeyType.p384);
    var con = wallet.getConnection(myDid);
    wallet.wallet.storeConnection(replyUrl!, 'Kaprion', con!.hdPath,
        keyType: KeyType.p384);
    logger.d(await wallet.wallet.getPublicKey(con.hdPath, KeyType.p384));
    var propose = ProposeCredential(
        id: threadId,
        threadId: threadId,
        parentThreadId: invitation.id,
        from: myDid,
        to: [invitation.from!]);

    sendMessage(myDid, replyUrl, wallet, propose, invitation.from!);
  } else {
    try {
      dynamic jsonData = invitation.attachments!.first.data.json!;
      var plain = DidcommPlaintextMessage.fromJson(
          jsonData is List ? jsonData.first : jsonData);
      plain.from ??= invitation.from;
      return handleDidcommMessage(plain.toString());
    } catch (e) {
      logger.e(e);
      throw Exception('OOB Message with no proper attachment: $e');
    }
  }
  return true;
}

String determineReplyUrl(String? replyUrl, List<String>? replyTo,
    [String? myDid]) {
  logger.d(replyTo);
  if (replyUrl != null) {
    return replyUrl;
  } else if (replyTo != null && replyTo.isNotEmpty) {
    for (var url in replyTo) {
      if (url.startsWith('http')) return url;
    }
  } else if (myDid != null) {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var con = wallet.getConnection(myDid);
    if (con == null) {
      throw Exception('no connection');
    }
    return con.otherDid;
  }
  throw Exception('cant find a replyUrl');
}

sendMessage(String myDid, String otherEndpoint, WalletProvider wallet,
    DidcommPlaintextMessage message, String receiverDid) async {
  var myPrivateKey = await wallet.privateKeyForConnectionDidAsJwk(myDid);
  DidDocument recipientDDO;
  if (receiverDid.startsWith('did:keri')) {
    if (receiverDid.contains('?')) {
      var res = await get(Uri.parse(
          'https://mags.kt.et.kaprion.de/VcIssuerSp/dereference?didUrl=$receiverDid'));
      var jsonBody = jsonDecode(res.body);
      var dd = DidDocument.fromJson(jsonBody['contentStream']['didDocument']);
      logger.d(dd.toJson());
      recipientDDO = dd.resolveKeyIds();
      var did = receiverDid.split('?').first;
      wallet.storeConfig(did, recipientDDO.toString());
    } else {
      var ddo = wallet.getConfig(receiverDid);
      logger.d(ddo);
      if (ddo != null) {
        recipientDDO = DidDocument.fromJson(ddo);
      } else {
        throw Exception('no ddo');
      }
    }
  } else {
    recipientDDO = (await resolveDidDocument(receiverDid))
        .resolveKeyIds()
        .convertAllKeysToJwk();
  }
  if (message.type != DidcommMessages.emptyMessage) {
    wallet.storeConversation(message, myDid);
  }

  var pubKey =
      (recipientDDO.keyAgreement!.first as VerificationMethod).publicKeyJwk!;
  if (pubKey['kid'] == null) {
    pubKey['kid'] = (recipientDDO.keyAgreement!.first as VerificationMethod).id;
  }
  var encrypted = DidcommEncryptedMessage.fromPlaintext(
      senderPrivateKeyJwk: myPrivateKey!,
      recipientPublicKeyJwk: [pubKey],
      plaintext: message);

  logger.d(encrypted.toJson());

  if (otherEndpoint.startsWith('http')) {
    logger.d('send message to $otherEndpoint');
    var res = await post(Uri.parse(otherEndpoint),
        body: encrypted.toString(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 300), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (res.statusCode == 201 || res.statusCode == 200) {
      logger.d('getResponse: ${res.body}');

      if (message is Presentation) {
        String type = '';
        for (var p in message.verifiablePresentation) {
          if (p.verifiableCredential != null) {
            for (var c in p.verifiableCredential!) {
              type += '''${getTypeToShow(c.type)}, \n''';
            }
          }
        }
        type = type.substring(0, type.length - 3);

        showModalBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline:
                      AppLocalizations.of(context)!.presentationSuccessful,
                  success: true,
                  amount: CurrencyDisplay(
                      amount: type,
                      symbol: '',
                      mainFontSize: 18,
                      centered: true),
                ),
              );
            });
      }
      logger.d(res.headers);
      var contentType = res.headers['content-type'];
      logger.d(contentType);

      if (contentType!.startsWith('application/json')) {
        // here we assume we talk with our agent
        Map<String, dynamic> body = jsonDecode(res.body);
        if (body.containsKey('responses')) {
          var responses = body['responses'] as List;
          if (responses.isNotEmpty) {
            handleDidcommMessage(jsonEncode(responses.first));
          }
        } else {
          handleDidcommMessage(res.body);
          //wallet.addRelayedDid(myDid);
          //TODO: appropriate Reaction
          //throw Exception('Something went wrong');
        }
      } else if (contentType.startsWith('application/didcomm-encrypted+json') ||
          contentType.startsWith('application/didcomm-signed+json') ||
          contentType.startsWith('application/didcomm-plain+json')) {
        handleDidcommMessage(res.body);
      } else {
        //we assume we get message over relay
        logger.d('need relay: $myDid');
        wallet.addRelayedDid(myDid);
      }
    } else {
      if (message is Presentation) {
        for (var pres in message.verifiablePresentation) {
          if (pres.verifiableCredential != null) {
            for (var cred in pres.verifiableCredential!) {
              wallet.storeExchangeHistoryEntry(
                  getHolderDidFromCredential(cred.toJson()),
                  DateTime.now(),
                  'present failed',
                  message.to!.first);
            }
          }
        }
        showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
            .presentationFailed);
      }

      logger.d(res.statusCode);
      logger.d(res.body);
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
    }
  } else {
    throw Exception('We do not support other transports');
  }
}

bool handleProblemReport(ProblemReport message, WalletProvider wallet) {
  logger.d(message.toJson());
  showErrorMessage('Problem Report', message.interpolateComment());
  return false;
}

void showErrorMessage(String headline, [String? subtext]) {
  showModalBottomSheet(
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10))),
      context: navigatorKey.currentContext!,
      builder: (context) {
        return ModalDismissWrapper(
          closeSeconds: 4,
          child: PaymentFinished(
            headline: headline,
            success: false,
            amount: CurrencyDisplay(
                width: 350,
                amount: subtext ?? '',
                symbol: '',
                mainFontSize: 18,
                centered: true),
          ),
        );
      });
}
