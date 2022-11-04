import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanner extends StatelessWidget {
  const QrScanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Scanner')),
      body: MobileScanner(
          allowDuplicates: false,
          onDetect: (barcode, args) {
            if (barcode.rawValue != null) {
              final String code = barcode.rawValue!;
              debugPrint('Barcode found! $code');
              handleDidcommMessage(code);
              Navigator.of(context).pop();
            }
          }),
    );
  }
}
