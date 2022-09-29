import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';

List<String> _supportedAttachments = [
  'dif/presentation-exchange/definitions@v2.0',
  'aries/ld-proof-vc@v1.0',
  'aries/ld-proof-vc-detail@v1.0',
];

Future<bool> handleDiscoverFeatureQuery(
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

  sendMessage(myDid, determineReplyUrl(message.replyUrl, message.replyTo),
      wallet, answer, message.from!);
  return false;
}
