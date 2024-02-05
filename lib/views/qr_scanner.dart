import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_member_card.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

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
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                  handleLnurl(code);
                } else if (code.startsWith('lntb')) {
                  logger.d('LN-Invoice (testnet) found');
                  payInvoiceInteraction(code);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                } else if (code.startsWith('lnbc') || code.startsWith('LNBC')) {
                  logger.d('LN-Invoice found');
                  payInvoiceInteraction(code, isMainnet: true);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                } else if (code.startsWith('openid-credential-offer')) {
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                  handleOfferOidc(code);
                } else if (code.startsWith('openid-presentation-request')) {
                  handlePresentationRequestOidc(code);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
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

                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                  Provider.of<NavigationProvider>(context, listen: false)
                      .changePage([6],
                          webViewUrl: uriToCall
                              .toString()
                              .replaceAll('wid=', 'wid=${wallet.lndwId}'));
                } else if (code.contains('ooburl')) {
                  handleOobUrl(code);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                } else if (code.contains('oobid')) {
                  handleOobId(code);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                } else if (code.startsWith('https://wallet.bccm.dev')) {
                  //TODO: Handle app-link
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                } else if (code.length < 35) {
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => AddMemberCard(
                          initialNumber: code,
                          initialBarcodeType: barcode.format.toString())));
                } else {
                  handleDidcommMessage(code);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .goBack();
                }
              }
            }));
  }
}
