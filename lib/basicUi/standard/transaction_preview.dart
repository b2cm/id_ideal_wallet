import 'currency_display.dart';
import 'package:flutter/material.dart';

class TransactionPreview extends StatelessWidget {
  const TransactionPreview(
      {super.key,
      required this.title,
      required this.amount,
      this.hasReceipt = false});

  final String title;
  final CurrencyDisplay amount;
  final bool hasReceipt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: Row(
        children: [
          // title
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
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
