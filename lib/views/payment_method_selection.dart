import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../provider/wallet_provider.dart';

class PaymentMethodSelector extends StatefulWidget {
  final List<VerifiableCredential> paymentMethods;

  const PaymentMethodSelector({super.key, required this.paymentMethods});

  @override
  PaymentMethodSelectorState createState() => PaymentMethodSelectorState();
}

class PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Text(AppLocalizations.of(context)!.selectPaymentMethod,
              style: const TextStyle(color: Colors.black)),
        ),
        body: SafeArea(
          child: Consumer<WalletProvider>(builder: (context, wallet, child) {
            return ListView.builder(
                itemCount: widget.paymentMethods.length,
                itemBuilder: (context, index) {
                  return RadioListTile(
                      title: Text(widget
                          .paymentMethods[index].credentialSubject['name']),
                      subtitle: Text(wallet
                          .balance[widget.paymentMethods[index].id!]!
                          .toStringAsFixed(2)),
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (newIndex) {
                        if (newIndex != null) {
                          setState(() {
                            selectedIndex = index;
                          });
                        }
                      });
                });
          }),
        ),
        persistentFooterButtons: [
          Column(
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              const SizedBox(
                height: 5,
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(selectedIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: const Text('Ok'),
              )
            ],
          )
        ]);
  }
}
