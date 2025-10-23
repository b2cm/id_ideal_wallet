import 'dart:async';

import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/views/add_member_card.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

class QrScanner extends StatefulWidget {
  final bool inApp;

  const QrScanner({super.key, this.inApp = true});

  @override
  QrScannerState createState() => QrScannerState();
}

class QrScannerState extends State<QrScanner> {
  bool waiting = false;
  Timer? t;
  double scaleFactor = 1.0;
  double baseScaleFactor = 1.0;
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  handleBarcode(Barcode barcode) {
    final String code = barcode.rawValue!;
    logger.d(
        'Barcode found! $code, type: ${barcode.type.name}, format: ${barcode.format.name}');
    if (widget.inApp) {
      var navigator = Provider.of<NavigationProvider>(context, listen: false);
      if (code.length < 35 && !code.contains('://')) {
        navigator.goBack();
        navigateClassic(AddMemberCard(
            initialNumber: code, initialBarcodeType: barcode.format.name));
      } else {
        navigator.goBack();
        navigator.handleLink(code);
      }
    } else {
      //from webview
      Navigator.of(context).pop(code);
    }
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StyledScaffoldTitle(
          leading: !widget.inApp,
          title: 'QR-Code Scanner',
          child: GestureDetector(
            onScaleStart: (details) {
              baseScaleFactor = scaleFactor;
            },
            onScaleUpdate: (details) {
              setState(() {
                scaleFactor = baseScaleFactor * details.scale;
                logger.d(scaleFactor);
                controller.setZoomScale(scaleFactor);
              });
            },
            child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final List<Barcode> codes = capture.barcodes;
                  var barcode = codes.first;
                  if (barcode.rawValue != null) {
                    controller.stop();
                    t = Timer(const Duration(milliseconds: 400),
                        () => handleBarcode(barcode));
                    setState(() {
                      waiting = true;
                    });
                  }
                }),
          ),
        ),
        if (waiting)
          const Opacity(
            opacity: 0.8,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (waiting)
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                DefaultTextStyle(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  child: Text(
                    '${AppLocalizations.of(context)!.waiting}\n${AppLocalizations.of(context)!.waitingQrData}',
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }
}
