import 'package:flutter/material.dart';

class Heading extends StatelessWidget {
  const Heading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: FractionallySizedBox(
        widthFactor: 1,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 7, 0, 0),
            child: Text(
              text,
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
            ),
          ),
        ),
      ),
    );
  }
}
