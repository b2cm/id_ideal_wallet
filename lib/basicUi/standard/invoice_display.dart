import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'currency_display.dart';

class InvoiceDisplay extends StatelessWidget {
  const InvoiceDisplay(
      {super.key,
      required this.invoice,
      required this.amount,
      required this.memo});

  final String invoice;
  final CurrencyDisplay amount;
  final String memo;

  @override
  Widget build(BuildContext context) {
    // return a qr code, the amount as CurrencyDisplay, the memo as text
    return Scaffold(
      body: Column(
        // all items centered
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.requestPayment,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          QrImageView(
            data: invoice,
            version: QrVersions.auto,
            size: 300,
          ),
          const SizedBox(height: 20),
          amount,
          const SizedBox(height: 10),
          // text formatted as a paragraph, justified, 10px padding, overflow ellipsis after 10 lines
          memo != ''
              ? Container(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    memo,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 7,
                  ),
                )
              : const SizedBox(height: 0),
          const SizedBox(height: 10),
          // outlined button cancel
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context)!.back,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // outlined button cancel
          OutlinedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invoice));
              ScaffoldMessenger.of(navigatorKey.currentContext!)
                  .showSnackBar(SnackBar(
                duration: const Duration(seconds: 2),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(30.0),
                  ),
                ),
                backgroundColor: Colors.black.withOpacity(0.6),
                behavior: SnackBarBehavior.floating,
                content: Text(AppLocalizations.of(navigatorKey.currentContext!)!
                    .copyNote),
              ));
            },
            child: Text(
              AppLocalizations.of(context)!.copy,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
