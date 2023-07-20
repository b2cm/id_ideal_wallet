import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_member_card.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class QrScanner extends StatelessWidget {
  const QrScanner({Key? key}) : super(key: key);

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
                if (code.startsWith('lntb')) {
                  logger.d('LN-Invoice (testnet) found');
                  payInvoiceInteraction(code);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (code.startsWith('lnbc') || code.startsWith('LNBC')) {
                  logger.d('LN-Invoice found');
                  payInvoiceInteraction(code, isMainnet: true);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (code.startsWith('openid-credential-offer')) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  handleOfferOidc(code);
                } else if (code.startsWith('openid-presentation-request')) {
                  handlePresentationRequestOidc(code);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (code.contains('webview')) {
                  var asUri = Uri.parse(code);
                  var uriToCall = Uri.parse(asUri.queryParameters['url']!);
                  var wallet = Provider.of<WalletProvider>(
                      navigatorKey.currentContext!,
                      listen: false);
                  // var newQuery = {'wid': wallet.lndwId};
                  // newQuery.addAll(uriToCall.queryParameters);
                  // logger.d(newQuery);
                  // var newUriToCall =
                  //     uriToCall.replace(queryParameters: newQuery);
                  // logger.d(newUriToCall);
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => WebViewWindow(
                          initialUrl:
                              '$uriToCall${uriToCall.toString().contains('?') ? '&' : '?'}wid=${wallet.lndwId}',
                          title: asUri.queryParameters['title'] ?? '')));
                } else if (code.contains('ooburl')) {
                  handleOobUrl(code);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (code.length < 35) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => AddMemberCard(
                          initialNumber: code,
                          initialBarcodeType: barcode.format)));
                } else {
                  handleDidcommMessage(code);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            }));
  }
}
