import 'package:flutter/material.dart';

import 'currency_display.dart';

class PaymentFinished extends StatelessWidget {
  const PaymentFinished(
      {super.key,
      required this.success,
      required this.headline,
      required this.amount,
      this.additionalInfo = const SizedBox(height: 0)});

  final bool success;
  final CurrencyDisplay amount;
  final String headline;
  final Widget additionalInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      // all items centered
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        success
            ? const Image(
                image: AssetImage("assets/icons/circle-check-regular.png"),
                height: 85,
                width: 85)
            : const Image(
                image: AssetImage("assets/icons/circle-xmark-regular.png"),
                height: 85,
                width: 85),
        const SizedBox(height: 20),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        amount,
        additionalInfo
      ],
    );
  }
}
