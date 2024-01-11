import 'package:flutter/material.dart';

import 'currency_display.dart';

class TransactionPreview extends StatelessWidget {
  const TransactionPreview(
      {super.key,
      required this.title,
      required this.amount,
      this.hasReceipt = false,
      this.wide = false});

  final String title;
  final CurrencyDisplay amount;
  final bool hasReceipt;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // title
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Text(
              title,
              style: Theme.of(context).primaryTextTheme.bodyMedium,
            ),
          ),
          // amount
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
            child: amount,
          ),
          // receipt
          if (hasReceipt)
            Container(
              padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
              child: const Icon(Icons.receipt),
            ),
        ],
      ),
    );
  }
}
