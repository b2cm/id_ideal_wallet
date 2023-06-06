import 'package:flutter/material.dart';

class CurrencyDisplay extends StatelessWidget {
  const CurrencyDisplay(
      {super.key,
      required this.amount,
      required this.symbol,
      this.mainFontSize = 20,
      this.centered = false});

  final String symbol;
  final dynamic amount;
  final double mainFontSize;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        amount is String
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                width: 350,
                child: Text(
                  amount,
                  maxLines: 6,
                  style: TextStyle(
                    fontSize: mainFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ))
            : amount,
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            " $symbol",
            style: TextStyle(
              fontSize: mainFontSize * 0.7,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 255, 86, 86),
            ),
          ),
        ),
      ],
    );
  }
}
