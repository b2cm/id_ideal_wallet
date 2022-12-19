import 'dart:convert';
import 'dart:io';

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


Future<String> resolveVCShortLink(String message) async {

  String url  = message.split(',')[1].trim();

  print(url);

  HttpClient client = HttpClient();
  HttpClientRequest request = await client.getUrl(Uri.parse(url));
  HttpClientResponse response = await request.close();
  String responseBody = await response.transform(utf8.decoder).join();

  print(responseBody);

  //return "http://wallet.de/?_oob=eyJpZCI6ImEzMDA0Njc4LWZmOTUtNDNmNC1iMDEyLWIyNjA2MWNiZDBiNCIsInR5cCI6ImFwcGxpY2F0aW9uL2RpZGNvbW0tcGxhaW4ranNvbiIsInR5cGUiOiJodHRwczovL2RpZGNvbW0ub3JnL291dC1vZi1iYW5kLzIuMC9pbnZpdGF0aW9uIiwiZnJvbSI6ImRpZDprZXk6ejZMU3JCVHdwYlhHM2ttQmdtdUFRazh6eVg2eDU1N0JpNlVXM2VWb1RHZ1FFcG1NIiwidGhpZCI6ImEzMDA0Njc4LWZmOTUtNDNmNC1iMDEyLWIyNjA2MWNiZDBiNCIsImJvZHkiOnsiYWNjZXB0IjpbImRpZGNvbW0vdjIiXX0sImF0dGFjaG1lbnRzIjpbeyJkYXRhIjp7Impzb24iOnsiaWQiOiJhMzAwNDY3OC1mZjk1LTQzZjQtYjAxMi1iMjYwNjFjYmQwYjQiLCJ0eXBlIjoiaHR0cHM6Ly9kaWRjb21tLm9yZy9pc3N1ZS1jcmVkZW50aWFsLzMuMC9vZmZlci1jcmVkZW50aWFsIiwidGhpZCI6ImEzMDA0Njc4LWZmOTUtNDNmNC1iMDEyLWIyNjA2MWNiZDBiNCIsImJvZHkiOnt9LCJhdHRhY2htZW50cyI6W3siZGF0YSI6eyJqc29uIjp7ImNyZWRlbnRpYWwiOnsiQGNvbnRleHQiOlsiaHR0cHM6Ly93d3cudzMub3JnLzIwMTgvY3JlZGVudGlhbHMvdjEiLCJodHRwczovL3NjaGVtYS5vcmciXSwidHlwZSI6WyJWZXJpZmlhYmxlQ3JlZGVudGlhbCIsIlBpY3R1cmUiXSwiY3JlZGVudGlhbFN1YmplY3QiOnsiZGF0YSI6ImVtcHR5IiwiaWQiOiJkaWQ6a2V5OjAwMCJ9LCJpc3N1ZXIiOiJkaWQ6a2V5Ono2TWtxdlFVRGFDSjFFR2ZUZXd3cDk3Q1VDV0ZBQlpkeEM3V2p5TGIyR2ZtZExURSIsImlzc3VhbmNlRGF0ZSI6IjIwMjItMTItMTZUMTQ6NTI6MzcuNTE5NjQ3In0sIm9wdGlvbnMiOnsicHJvb2ZUeXBlIjoiRWQyNTUxOVNpZ25hdHVyZSJ9fX0sImlkIjoiY2EzN2Q2Y2YtZjI5YS00ZmZjLTkwNWQtNGE5ZDE5NmNiNjI4IiwibWVkaWFfdHlwZSI6ImFwcGxpY2F0aW9uL2pzb24iLCJmb3JtYXQiOiJhcmllcy9sZC1wcm9vZi12Yy1kZXRhaWxAdjEuMCJ9XSwicmVwbHlfdG8iOlsiaHR0cDovL2xvY2FsaG9zdDo4MDgxL3JlY2VpdmUiLCJ4bXBwOnRlc3R1c2VyMkBsb2NhbGhvc3QiXX19fV0sInJlcGx5X3RvIjpbImh0dHA6Ly9sb2NhbGhvc3Q6ODA4MS9yZWNlaXZlIiwieG1wcDp0ZXN0dXNlcjJAbG9jYWxob3N0Il19";
  // return "http://wallet.de/?_oob=eyJpZCI6ImMwNTQzOTk4LTYzMTItNDI0OS05NmViLWQ2NDBmYTY2NTIyMSIsInR5cCI6ImFwcGxpY2F0aW9uL2RpZGNvbW0tcGxhaW4ranNvbiIsInR5cGUiOiJodHRwczovL2RpZGNvbW0ub3JnL291dC1vZi1iYW5kLzIuMC9pbnZpdGF0aW9uIiwiZnJvbSI6ImRpZDprZXk6ejZMU3JCVHdwYlhHM2ttQmdtdUFRazh6eVg2eDU1N0JpNlVXM2VWb1RHZ1FFcG1NIiwidGhpZCI6ImMwNTQzOTk4LTYzMTItNDI0OS05NmViLWQ2NDBmYTY2NTIyMSIsImJvZHkiOnsiYWNjZXB0IjpbImRpZGNvbW0vdjIiXX0sImF0dGFjaG1lbnRzIjpbeyJkYXRhIjp7Impzb24iOnsiaWQiOiJjMDU0Mzk5OC02MzEyLTQyNDktOTZlYi1kNjQwZmE2NjUyMjEiLCJ0eXBlIjoiaHR0cHM6Ly9kaWRjb21tLm9yZy9pc3N1ZS1jcmVkZW50aWFsLzMuMC9vZmZlci1jcmVkZW50aWFsIiwidGhpZCI6ImMwNTQzOTk4LTYzMTItNDI0OS05NmViLWQ2NDBmYTY2NTIyMSIsImJvZHkiOnt9LCJhdHRhY2htZW50cyI6W3siZGF0YSI6eyJqc29uIjp7ImNyZWRlbnRpYWwiOnsiQGNvbnRleHQiOlsiaHR0cHM6Ly93d3cudzMub3JnLzIwMTgvY3JlZGVudGlhbHMvdjEiLCJodHRwczovL3NjaGVtYS5vcmciXSwidHlwZSI6WyJWZXJpZmlhYmxlQ3JlZGVudGlhbCIsIkFMRzJCZXNjaGVpZCJdLCJjcmVkZW50aWFsU3ViamVjdCI6eyJnaXZlbk5hbWUiOiJNYXgiLCJmYW1pbHlOYW1lIjoiTXVzdGVybWFubiIsImJpcnRoRGF0ZSI6IjIzLjA5LjE5ODciLCJpZCI6ImRpZDprZXk6MDAwIn0sImlzc3VlciI6ImRpZDprZXk6ejZNa3F2UVVEYUNKMUVHZlRld3dwOTdDVUNXRkFCWmR4QzdXanlMYjJHZm1kTFRFIiwiaXNzdWFuY2VEYXRlIjoiMjAyMi0xMi0xNlQxNToyNDo0Mi4yODY3NDYifSwib3B0aW9ucyI6eyJwcm9vZlR5cGUiOiJFZDI1NTE5U2lnbmF0dXJlIn19fSwiaWQiOiI1NWJmZDNiOS03ZWFiLTQwOWYtOTcwYy1jYmEwNjY2NDA0NzgiLCJtZWRpYV90eXBlIjoiYXBwbGljYXRpb24vanNvbiIsImZvcm1hdCI6ImFyaWVzL2xkLXByb29mLXZjLWRldGFpbEB2MS4wIn1dLCJyZXBseV90byI6WyJodHRwOi8vbG9jYWxob3N0OjgwODEvcmVjZWl2ZSIsInhtcHA6dGVzdHVzZXIyQGxvY2FsaG9zdCJdfX19XSwicmVwbHlfdG8iOlsiaHR0cDovL2xvY2FsaG9zdDo4MDgxL3JlY2VpdmUiLCJ4bXBwOnRlc3R1c2VyMkBsb2NhbGhvc3QiXX0=";
  return responseBody;
}

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
