import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_multihash/dart_multihash.dart' as multihash;
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:json_path/json_path.dart';
import 'package:json_schema/json_schema.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class QrRender extends StatefulWidget {
  final VerifiableCredential credential;
  final SatoshiAmount? amount;
  final String? memo;
  final VerifiableCredential? paymentContext;

  const QrRender(
      {Key? key,
      required this.credential,
      this.amount,
      this.memo,
      this.paymentContext})
      : super(key: key);

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

    String? paymentId = widget.paymentContext?.id;
    String? paymentType =
        widget.paymentContext?.credentialSubject['paymentType'];

    var id = widget.credential.id ??
        getHolderDidFromCredential(widget.credential.toJson());
    if (id == '') {
      Attachment? paymentAtt;
      // Offer Credential
      if (paymentId != null) {
        if (paymentType == 'SimulatedPayment') {
          paymentAtt = Attachment(
              format: 'lnInvoice',
              data: AttachmentData(json: {
                'type': 'lnInvoice',
                'lnInvoice': widget.amount!.toEuro().toStringAsFixed(2)
              }));
          wallet.fakePay(paymentId, widget.amount!.toEuro() * -1);
        } else {
          var invoiceMap = await createInvoice(
              wallet.getLnInKey(paymentId)!, widget.amount!,
              memo: widget.memo);

          wallet.newPayment(
              paymentId, invoiceMap['checking_id'], '', widget.amount!);

          paymentAtt = Attachment(
              format: 'lnInvoice',
              data: AttachmentData(json: {
                'type': 'lnInvoice',
                'lnInvoice': invoiceMap['payment_request']
              }));
        }
      }
      var myDid = await wallet.newConnectionDid();

      wallet.addRelayedDid(myDid);

      var offer = OfferCredential(
        from: myDid,
        detail: [
          LdProofVcDetail(
              credential: widget.credential,
              options: LdProofVcDetailOptions(proofType: 'Ed25519Signature')),
        ],
        replyUrl: '$relay/buffer/$myDid',
      );

      if (paymentAtt != null) {
        offer.attachments!.add(paymentAtt);
      }

      var bufferId = const Uuid().v4();
      await post(Uri.parse('$relay/buffer/$bufferId'), body: offer.toString());

      wallet.storeConversation(offer, myDid);

      var hash = sha256.convert(utf8.encode(jsonEncode(offer)));

      var oob = OutOfBandMessage(from: myDid, attachments: [
        Attachment(
            data: AttachmentData(
                links: ['$relay/get/$bufferId'],
                hash: base64Encode(multihash.Multihash.encode(
                    'sha2-256', Uint8List.fromList(hash.bytes)))))
      ]);
      var url = oob.toUrl('http', 'ver', '');
      qrData = url;
      setState(() {});
    } else {
      // Propose Presentation
      var idField = InputDescriptorField(
          path: [JsonPath(r'$.id'), JsonPath(r'$.credentialSubject.id')],
          filter: JsonSchema.create({
            'type': 'string',
            'pattern': widget.credential.id ??
                widget.credential.credentialSubject['id']
          }));
      var type = getTypeToShow(widget.credential.type);
      var typeField = InputDescriptorField(
          path: [JsonPath(r'$.type')],
          filter: JsonSchema.create({
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
      await post(Uri.parse('$relay/buffer/$bufferId'),
          body: message.toString());

      wallet.storeConversation(message, newConnDid);

      var hash = sha256.convert(utf8.encode(jsonEncode(message)));

      var oob = OutOfBandMessage(from: newConnDid, attachments: [
        Attachment(
            data: AttachmentData(
                links: ['$relay/get/$bufferId'],
                hash: base64Encode(multihash.Multihash.encode(
                    'sha2-256', Uint8List.fromList(hash.bytes)))))
      ]);
      var url = oob.toUrl('http', 'ver', '');
      qrData = url;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: getHolderDidFromCredential(widget.credential.toJson()) == ''
            ? AppLocalizations.of(context)!.sellCredentialTitle
            : AppLocalizations.of(context)!.presentCredential,
        child: qrData.isEmpty
            ? const CircularProgressIndicator()
            : QrImageView(data: qrData));
  }
}
