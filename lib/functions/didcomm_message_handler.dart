import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/discover_feature.dart';
import 'package:id_ideal_wallet/functions/issue_credential.dart';
import 'package:id_ideal_wallet/functions/present_proof.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

Future<bool> handleDidcommMessage(String message) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);
  var plaintext = await getPlaintext(message, wallet);
  if (plaintext.attachments != null && plaintext.attachments!.isNotEmpty) {
    for (var a in plaintext.attachments!) {
      try {
        await a.data.resolveData();
      } catch (e) {
        logger.e(e);
      }
    }
  }
  switch (plaintext.type) {
    case 'https://didcomm.org/out-of-band/2.0/invitation':
      return handleInvitation(
          OutOfBandMessage.fromJson(plaintext.toJson()), wallet);
    case 'https://didcomm.org/issue-credential/3.0/propose-credential':
      return handleProposeCredential(
          ProposeCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/offer-credential':
      return handleOfferCredential(
          OfferCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/request-credential':
      return handleRequestCredential(
          RequestCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/issue-credential':
      return handleIssueCredential(
          IssueCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/present-proof/3.0/propose-presentation':
      return handleProposePresentation(
          ProposePresentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/present-proof/3.0/request-presentation':
      return handleRequestPresentation(
          RequestPresentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/present-proof/3.0/presentation':
      return handlePresentation(
          Presentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/report-problem/2.0/problem-report':
      return handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/discover-features/2.0/queries':
      return handleDiscoverFeatureQuery(
          QueryMessage.fromJson(plaintext.toJson()), wallet);

    default:
      throw Exception('Unsupported message type');
  }
}

Future<DidcommPlaintextMessage> getPlaintext(
    String message, WalletProvider wallet) async {
  logger.d(message);
  try {
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
  } catch (e) {
    try {
      var encrypted = DidcommEncryptedMessage.fromJson(message);
      var decrypted = await encrypted.decrypt(wallet.wallet);
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
      try {
        var signed = DidcommSignedMessage.fromJson(message);
        if (signed.payload is DidcommPlaintextMessage) {
          return signed.payload as DidcommPlaintextMessage;
        } else {
          return getPlaintext(signed.payload.toString(), wallet);
        }
      } catch (e) {
        try {
          var plain = DidcommPlaintextMessage.fromJson(message);
          return plain;
        } catch (e) {
          throw Exception(
              'Unexpected message format - only expect Signed or encrypted messages: $e');
        }
      }
    }
  }

  throw Exception(
      'Unexpected message format - only expect Signed or encrypted messages');
}

Future<bool> handleInvitation(
    OutOfBandMessage invitation, WalletProvider wallet) async {
  if (invitation.accept != null &&
      !invitation.accept!.contains(DidcommProfiles.v2)) {
    //better: send problem report
    throw Exception('counterpart do not speak didcommv2');
  }

  if (invitation.goalCode != null && invitation.goalCode == 'streamlined-vp') {
    // counterpart wants to ask for presentation
    var threadId = const Uuid().v4();
    var myDid = await wallet.newConnectionDid();
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
        determineReplyUrl(invitation.replyUrl, invitation.replyTo),
        wallet,
        propose,
        invitation.from!);
  } else {
    throw UnimplementedError('more goalcodes are not known yet');
  }
  return true;
}

String determineReplyUrl(String? replyUrl, List<String>? replyTo) {
  if (replyUrl != null) {
    return replyUrl;
  } else {
    if (replyTo == null) throw Exception(' cant find a replyUrl');
    for (var url in replyTo) {
      if (url.startsWith('http')) return url;
    }
  }
  throw Exception('cant find a replyUrl');
}

sendMessage(String myDid, String otherEndpoint, WalletProvider wallet,
    DidcommPlaintextMessage message, String receiverDid) async {
  var myPrivateKey = await wallet.privateKeyForConnectionDidAsJwk(myDid);
  var recipientDDO = (await resolveDidDocument(receiverDid))
      .resolveKeyIds()
      .convertAllKeysToJwk();
  if (message.type != DidcommMessages.emptyMessage.value) {
    wallet.storeConversation(message, myDid);
  }
  var encrypted = DidcommEncryptedMessage.fromPlaintext(
      senderPrivateKeyJwk: myPrivateKey!,
      recipientPublicKeyJwk: [
        (recipientDDO.keyAgreement!.first as VerificationMethod).publicKeyJwk!
      ],
      plaintext: message);

  if (otherEndpoint.startsWith('http')) {
    logger.d('send message to $otherEndpoint');
    post(Uri.parse(otherEndpoint), body: encrypted.toString());
  } else {
    throw Exception('We do not support other transports');
  }
}

bool handleProblemReport(ProblemReport message, WalletProvider wallet) {
  return false;
}
