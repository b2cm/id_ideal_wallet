import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
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
              var navigator =
                  Provider.of<NavigationProvider>(context, listen: false);
              if (code.length < 35 && !code.contains('://')) {
                navigator.goBack();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AddMemberCard(
                        initialNumber: code,
                        initialBarcodeType: barcode.format.name)));
              } else {
                navigator.goBack();
                navigator.handleLink(code);
              }
            }
          }),
    );
  }
}
