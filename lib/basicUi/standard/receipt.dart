import 'package:flutter/material.dart';

import 'currency_display.dart';

class Receipt extends StatelessWidget {
  const Receipt(
      {super.key,
      required this.items,
      required this.total,
      this.title = 'Rechnung'});

  final List<ReceiptItem> items;
  final ReceiptItem total;
  final String title;

  @override
  Widget build(BuildContext context) {
    // return a light gray container with rounded corners, a bold headline and a list of items with associated prices and the total at the bottom
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(240, 229, 235, 235),
        borderRadius: BorderRadius.circular(15),
      ),
      // padding top and bottom 20, left and right 15
      padding: const EdgeInsets.fromLTRB(12, 15, 12, 15),
      child: Column(
        children: [
          // left aligned title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // description
          ...items,
          const SizedBox(height: 20),
          total
          // sum all items and display the total
        ],
      ),
    );
  }
}

// ReceiptItem is a widget that displays a label and an amount

class ReceiptItem extends StatelessWidget {
  const ReceiptItem({super.key, required this.label, required this.amount});

  final String label;
  final CurrencyDisplay amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(right: 10), child: amount),
      ],
    );
  }
}
