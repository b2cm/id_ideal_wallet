import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanner extends StatelessWidget {
  const QrScanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        currentlyActive: 1,
        title: 'QR-Code Scanner',
        child: MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
            onDetect: (capture) {
              final List<Barcode> codes = capture.barcodes;
              var barcode = codes.first;
              if (barcode.rawValue != null) {
                final String code = barcode.rawValue!;
                logger.d(
                    'Barcode found! $code, type: ${barcode.type.name}, format: ${barcode.format.name}');
                if (code.startsWith('LNURL') || code.startsWith('lnurl')) {
                  context.go('/');
                  handleLnurl(code);
                } else if (code.startsWith('lntb')) {
                  logger.d('LN-Invoice (testnet) found');
                  payInvoiceInteraction(code);
                  context.go('/');
                } else if (code.startsWith('lnbc') || code.startsWith('LNBC')) {
                  logger.d('LN-Invoice found');
                  payInvoiceInteraction(code, isMainnet: true);
                  context.go('/');
                } else if (code.startsWith('openid-credential-offer')) {
                  context.go('/');
                  handleOfferOidc(code);
                } else if (code.startsWith('openid-presentation-request')) {
                  handlePresentationRequestOidc(code);
                  context.go('/');
                }
                // } else if (code.contains('webview')) {
                //   var asUri = Uri.parse(code);
                //   var uriToCall = Uri.parse(asUri.queryParameters['url']!);
                //   var wallet = Provider.of<WalletProvider>(
                //       navigatorKey.currentContext!,
                //       listen: false);
                //   // var newQuery = {'wid': wallet.lndwId};
                //   // newQuery.addAll(uriToCall.queryParameters);
                //   // logger.d(newQuery);
                //   // var newUriToCall =
                //   //     uriToCall.replace(queryParameters: newQuery);
                //   // logger.d(newUriToCall);
                //   Navigator.of(context).pushReplacement(MaterialPageRoute(
                //       builder: (context) => WebViewWindow(
                //           initialUrl: uriToCall
                //               .toString()
                //               .replaceAll('wid=', 'wid=${wallet.lndwId}'),
                //           title: asUri.queryParameters['title'] ?? '')));
                // }
                else if (code.contains('ooburl')) {
                  handleOobUrl(code);
                  context.go('/');
                } else if (code.contains('oobid')) {
                  handleOobId(code);
                  context.go('/');
                } else if (code.startsWith('https://wallet.bccm.dev')) {
                  context.go(code);
                } else if (code.length < 35) {
                  context.go(
                      '/memberCard?initialNumber=$code&barcodeFormat=${barcode.format.name}');
                } else {
                  handleDidcommMessage(code);
                  context.go('/');
                }
              }
            }));
  }
}
