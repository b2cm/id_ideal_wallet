import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrRender extends StatelessWidget {
  final VerifiableCredential credential;
  final WalletStore wallet;

  const QrRender({Key? key, required this.credential, required this.wallet})
      : super(key: key);

  Future<String> _proposePresentation() async {
    var newConnDid = await wallet.getNextConnectionDID(KeyType.x25519);
    var message = ProposePresentation(
        from: newConnDid,
        replyUrl: '$relay/buffer/$newConnDid',
        presentationDefinition: [
          buildPresentationDefinitionForCredential(credential)
        ]);
    print(message);

    var oob = OutOfBandMessage(from: newConnDid, attachments: [
      Attachment(data: AttachmentData(json: message.toJson()))
    ]);
    var url = oob.toUrl('http', 'ver', '');
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credential anbieten'),
      ),
      body: Center(
        child: FutureBuilder(
          future: _proposePresentation(),
          builder: (context, AsyncSnapshot<String> snapshot) {
            if (snapshot.hasData) {
              return QrImage(data: snapshot.data!);
            } else if (snapshot.hasError) {
              return Text('Da ging was schief: ${snapshot.error}');
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}
