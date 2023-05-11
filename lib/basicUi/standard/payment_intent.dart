import 'package:action_slider/action_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'currency_display.dart';

class PaymentIntent extends StatelessWidget {
  const PaymentIntent(
      {super.key,
      required this.amount,
      required this.onPaymentAccepted,
      this.memo = ''});

  final CurrencyDisplay amount;
  final String memo;
  final void Function() onPaymentAccepted;

  @override
  Widget build(BuildContext context) {
    return Column(
      // all items centered
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Bezahlen",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ActionSlider.standard(
            backgroundColor: Colors.white,
            toggleColor: const Color.fromARGB(255, 35, 216, 108),
            action: (controller) {
              onPaymentAccepted();
            },
            child: Text(AppLocalizations.of(context)!.pay),
          ),
        ),
        TextButton(
          // dismiss modal on pressed
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ],
    );
  }
}
