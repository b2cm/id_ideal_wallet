import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanner extends StatelessWidget {
  const QrScanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'QR-Code Scanner',
        scanOnTap: () {},
        child: MobileScanner(
            allowDuplicates: false,
            onDetect: (barcode, args) {
              if (barcode.rawValue != null) {
                final String code = barcode.rawValue!;
                logger.d('Barcode found! $code');
                if (code.startsWith('lnbc') || code.startsWith('LNBC')) {
                  logger.d('LN-Invoice found');
                  //payInvoiceInteraction(code);
                } else if (code.startsWith('openid-credential-offer')) {
                  handleOfferOidc(code);
                } else if (code.startsWith('openid-presentation-request')) {
                  handlePresentationRequestOidc(code);
                } else {
                  handleDidcommMessage(code);
                }
                Navigator.of(context).pop();
              }
            }));
  }
}
