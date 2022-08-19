import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/presentation_request.dart';
import 'package:uuid/uuid.dart';

import './main.dart';

List<String> _supportedAttachments = [
  'dif/presentation-exchange/definitions@v2.0',
  'aries/ld-proof-vc@v1.0',
  'aries/ld-proof-vc-detail@v1.0',
];

Future<bool> handleDidcommMessage(
    WalletStore wallet, String message, BuildContext context) async {
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
      );

    case 'https://didcomm.org/issue-credential/3.0/request-credential':
      return _handleRequestCredential(
          RequestCredential.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/issue-credential/3.0/issue-credential':
      return _handleIssueCredential(
          IssueCredential.fromJson(plaintext.toJson()), wallet, context);

    case 'https://didcomm.org/present-proof/3.0/propose-presentation':
      return _handleProposePresentation(
          ProposePresentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/present-proof/3.0/request-presentation':
      return _handleRequestPresentation(
        RequestPresentation.fromJson(plaintext.toJson()),
        wallet,
        context,
      );

    case 'https://didcomm.org/present-proof/3.0/presentation':
      return _handlePresentation(
          Presentation.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/report-problem/2.0/problem-report':
      return _handleProblemReport(
          ProblemReport.fromJson(plaintext.toJson()), wallet);

    case 'https://didcomm.org/discover-features/2.0/queries':
      return _handleDiscoverFeatureQuery(
        QueryMessage.fromJson(plaintext.toJson()),
        wallet,
        context,
      );

    default:
      throw Exception('Unsupported message type');
  }
}

Future<DidcommPlaintextMessage> getPlaintext(
    String message, WalletStore wallet) async {
  print(message);
  try {
    var uri = Uri.parse(message);
    print('oob');
    if (uri.queryParameters.containsKey('_oob')) {
      var oob = oobMessageFromUrl(message);
      //For now we expect one message here
      if (oob.attachments!.isNotEmpty) {
        for (var a in oob.attachments!) {
          if (a.data.json == null) {
            print(a.data.links);
            await a.data.resolveData();
          }
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
      print('successfully decrypted');
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
        print('Nothing: $e');
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

String _determineReplyUrl(String? replyUrl, List<String>? replyTo) {
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

Future<bool> _handleDiscoverFeatureQuery(
  QueryMessage message,
  WalletStore wallet,
  BuildContext context,
) async {
  print('Query message received');
  List<Disclosure> features = [];

  for (var q in message.queries) {
    Iterable<String> result = [];
    //Note: we only accept wildcards at the end; if there is nothing, we look for exact match
    if (q.featureType == FeatureType.protocol) {
      result = DidcommMessages.requestCredential.allValues.where((element) =>
          q.match.endsWith('*')
              ? element.startsWith(q.match.substring(1, q.match.length))
              : element == q.match);
    } else if (q.featureType == FeatureType.attachmentFormat) {
      result = _supportedAttachments.where((element) => q.match.endsWith('*')
          ? element.startsWith(q.match.substring(1, q.match.length))
          : element == q.match);
    }
    if (result.isNotEmpty) {
      for (var found in result) {
        features.add(Disclosure(featureType: q.featureType, id: found));
      }
    }
  }

  //It is recommended to vary the answer
  features.shuffle();

  print('discoveredFeatures: $features');

  //TODO: for now we assume, that this is the first message from a Stranger (nothing else happened before)
  var myDid = await wallet.getNextConnectionDID(KeyType.x25519);

  var answer = DiscloseMessage(
      disclosures: features,
      from: myDid,
      replyUrl: 'http://localhost:8888/buffer/$myDid',
      threadId: message.threadId ?? message.id,
      to: [message.from!]);

  sendMessage(myDid, _determineReplyUrl(message.replyUrl, message.replyTo),
      wallet, answer, message.from!);
  return false;
}

Future<bool> _handleOfferCredential(
    OfferCredential message, WalletStore wallet, BuildContext context) async {
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
  if (entry == null ||
      entry.protocol == DidcommProtocol.discoverFeature.value) {
    //show data to user
    var res = await showDialog(
        context: context,
        builder: (BuildContext context) =>
            _buildOfferCredentialDialog(context, credential));

    print(res);
  }

  if (entry == null) {
    myDid = await wallet.getNextConnectionDID(KeyType.x25519);
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
  WalletStore wallet,
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
      replyUrl: 'http://localhost:8888/buffer/$myDid',
      threadId: offer.threadId ?? offer.id,
      from: myDid,
      to: [offer.from!]);
  sendMessage(myDid, _determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

_sendProposeCredential(
  OfferCredential offer,
  WalletStore wallet,
  String myDid,
) async {
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
      replyUrl: 'http://localhost:8888/buffer/$myDid',
      detail: [
        LdProofVcDetail(
            credential: newCred, options: offer.detail!.first.options)
      ]);

  //Sign attachment with credentialDid
  for (var a in message.attachments!) {
    await a.data.sign(wallet, credDid);
  }
  sendMessage(myDid, _determineReplyUrl(offer.replyUrl, offer.replyTo), wallet,
      message, offer.from!);
}

sendMessage(String myDid, String otherEndpoint, WalletStore wallet,
    DidcommPlaintextMessage message, String receiverDid) async {
  var myPrivateKey = await wallet.getPrivateKeyForConnectionDidAsJwk(myDid);
  print(receiverDid);
  var recipientDDO = (await resolveDidDocument(receiverDid))
      .resolveKeyIds()
      .convertAllKeysToJwk();
  if (message.type != DidcommMessages.emptyMessage.value) {
    await wallet.storeConversationEntry(message, myDid);
  }
  var encrypted = DidcommEncryptedMessage.fromPlaintext(
      senderPrivateKeyJwk: myPrivateKey!,
      recipientPublicKeyJwk: [
        (recipientDDO.keyAgreement!.first as VerificationMethod).publicKeyJwk!
      ],
      plaintext: message);

  if (otherEndpoint.startsWith('http')) {
    post(Uri.parse(otherEndpoint), body: encrypted.toString());
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

Future<bool> _handleIssueCredential(
    IssueCredential message, WalletStore wallet, BuildContext context) async {
  print('Mir wurde ein Credential ausgesetllt');
  var cred = message.credentials!.first;

  var entry = wallet.getConversationEntry(message.threadId!);
  if (entry == null) {
    throw Exception(
        'Something went wrong. There could not be an issue message without request');
  }
  var previosMessage = DidcommPlaintextMessage.fromJson(entry.lastMessage);
  print(previosMessage.type);
  if (previosMessage.type == DidcommMessages.requestCredential.value) {
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
        var ack = EmptyMessage(
            ack: [message.id], threadId: message.threadId ?? message.id);
        sendMessage(
            entry.myDid,
            _determineReplyUrl(message.replyUrl, message.replyTo),
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

bool _handleProposePresentation(
    ProposePresentation message, WalletStore wallet) {
  return false;
}

Future<bool> _handleRequestPresentation(
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
                  _determineReplyUrl(message.replyUrl, message.replyTo),
              receiverDid: message.from!,
              myDid: myDid,
              results: finalShow,
            )));
  }
  return false;
}

bool _handlePresentation(Presentation message, WalletStore wallet) {
  return false;
}

bool _handleProblemReport(ProblemReport message, WalletStore wallet) {
  return false;
}
