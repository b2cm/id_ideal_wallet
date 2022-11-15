import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:json_path/json_path.dart';
import 'package:json_schema2/json_schema2.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class QrRender extends StatefulWidget {
  final VerifiableCredential credential;

  const QrRender({Key? key, required this.credential}) : super(key: key);

  @override
  State<QrRender> createState() => QrRenderState();
}

class QrRenderState extends State<QrRender> {
  String qrData = '';

  @override
  void initState() {
    super.initState();
    _proposePresentation();
  }

  void _proposePresentation() async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var idField = InputDescriptorField(
        path: [JsonPath(r'$.id'), JsonPath(r'$.credentialSubject.id')],
        filter: JsonSchema.createSchema({
          'type': 'string',
          'pattern':
              widget.credential.id ?? widget.credential.credentialSubject['id']
        }));
    var type = widget.credential.type.firstWhere(
        (element) => element != 'VerifiableCredential',
        orElse: () => '');
    var typeField = InputDescriptorField(
        path: [JsonPath(r'$.type')],
        filter: JsonSchema.createSchema({
          'type': 'array',
          'contains': {'type': 'string', 'pattern': type}
        }));
    var newConnDid = await wallet.newConnectionDid();
    var message = ProposePresentation(
        from: newConnDid,
        replyUrl: '$relay/buffer/$newConnDid',
        presentationDefinition: [
          PresentationDefinition(inputDescriptors: [
            InputDescriptor(
                constraints:
                    InputDescriptorConstraints(fields: [idField, typeField]))
          ])
        ]);

    var bufferId = const Uuid().v4();
    await post(Uri.parse('$relay/buffer/$bufferId'), body: message.toString());

    wallet.storeConversation(message, newConnDid);

    var oob = OutOfBandMessage(from: newConnDid, attachments: [
      Attachment(
          data:
              AttachmentData(links: ['$relay/get/$bufferId'], hash: 'gfzuwqi'))
    ]);
    var url = oob.toUrl('http', 'ver', '');
    qrData = url;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffold(
        name: 'Credential vorzeigen',
        nameOnTap: () {},
        scanOnTap: () {},
        child: qrData.isEmpty
            ? const CircularProgressIndicator()
            : QrImageView(data: qrData));
  }
}
