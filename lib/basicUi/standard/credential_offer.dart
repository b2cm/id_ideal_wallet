import 'package:flutter/material.dart';

import 'receipt.dart';

class CredentialOfferDialog extends StatelessWidget {
  const CredentialOfferDialog({
    super.key,
    required this.credential,
    this.receipt,
  });

  final Widget credential;
  final Receipt? receipt;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 20),
      const Text("Credential Angebot",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      credential,
      const SizedBox(height: 20),
      receipt ??
          const SizedBox(
            height: 0,
          ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // button 1
          TextButton(
            // dismiss modal on pressed
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Abbrechen"),
          ),
          // button 2
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: receipt != null
                ? const Text("Zahlungspflichtig bestellen")
                : const Text("Ok"),
            // background color red
          ),
        ],
      ),
    ]);
  }
}
