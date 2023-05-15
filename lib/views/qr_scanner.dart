import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanner extends StatelessWidget {
  const QrScanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        currentlyActive: 1,
        title: 'QR-Code Scanner',
        child: MobileScanner(
            allowDuplicates: false,
            onDetect: (barcode, args) {
              if (barcode.rawValue != null) {
                final String code = barcode.rawValue!;
                logger.d(
                    'Barcode found! $code, type: ${barcode.type.name}, format: ${barcode.format.name}');
                if (code.startsWith('lnbc') ||
                    code.startsWith('LNBC') ||
                    code.startsWith('lntb')) {
                  logger.d('LN-Invoice found');
                  payInvoiceInteraction(code);
                  Navigator.of(context).pop();
                } else if (code.startsWith('openid-credential-offer')) {
                  handleOfferOidc(code);
                  Navigator.of(context).pop();
                } else if (code.startsWith('openid-presentation-request')) {
                  handlePresentationRequestOidc(code);
                  Navigator.of(context).pop();
                } else if (code.contains('webview')) {
                  var asUri = Uri.parse(code);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => WebViewWindow(
                          initialUrl: asUri.queryParameters['url']!,
                          title: asUri.queryParameters['title'] ?? '')));
                } else {
                  handleDidcommMessage(code);
                  Navigator.of(context).pop();
                }
              }
            }));
  }
}
