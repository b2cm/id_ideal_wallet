import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';

class TopUp extends StatefulWidget {
  const TopUp(
      {super.key,
      required this.onTopUpSats,
      required this.onTopUpFiat,
      this.paymentMethods});

  final void Function(SatoshiAmount, String, VerifiableCredential?) onTopUpSats;
  final void Function(int) onTopUpFiat;
  final List<VerifiableCredential>? paymentMethods;

  @override
  State<TopUp> createState() => _TopUpState();
}

class _TopUpState extends State<TopUp> {
  final List<bool> _selectedReceiveOption = <bool>[true, false];

  // textfield values
  final TextEditingController _amountControllerSats = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _amountControllerFiat = TextEditingController();

  int selectedPaymentMethod = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          widget.paymentMethods == null
                              ? const SizedBox(
                                  height: 0,
                                )
                              : Text(
                                  AppLocalizations.of(context)!.paymentMethod,
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .titleLarge),
                          widget.paymentMethods == null
                              ? ToggleButtons(
                                  direction: Axis.horizontal,
                                  onPressed: (int index) {
                                    setState(() {
                                      // The button that is tapped is set to true, and the others to false.
                                      for (int i = 0;
                                          i < _selectedReceiveOption.length;
                                          i++) {
                                        _selectedReceiveOption[i] = i == index;
                                      }
                                    });
                                  },
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  selectedBorderColor:
                                      const Color.fromARGB(255, 255, 86, 86),
                                  selectedColor: Colors.white,
                                  fillColor:
                                      const Color.fromARGB(255, 255, 86, 86),
                                  color: const Color.fromARGB(255, 255, 86, 86),
                                  borderColor:
                                      const Color.fromARGB(255, 255, 86, 86),
                                  borderWidth: 2,
                                  constraints: const BoxConstraints(
                                    minHeight: 30.0,
                                    minWidth: 80.0,
                                  ),
                                  isSelected: _selectedReceiveOption,
                                  children: <Widget>[
                                    Text('Crypto',
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .titleLarge),
                                    Text('Fiat',
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .titleLarge),
                                  ],
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: widget.paymentMethods!.length,
                                  itemBuilder: (context, index) {
                                    return RadioListTile(
                                        title: Text(widget
                                            .paymentMethods![index]
                                            .credentialSubject['paymentType']),
                                        value: index,
                                        groupValue: selectedPaymentMethod,
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              selectedPaymentMethod = index;
                                            });
                                          }
                                        });
                                  },
                                ),
                          const SizedBox(height: 20),
                          _selectedReceiveOption[0]
                              ?
                              // toogle button to switch between fiat and sats
                              TextField(
                                  controller: _amountControllerSats,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: AppLocalizations.of(context)!
                                        .amountSatoshi,
                                  ),
                                )
                              : // toogle button to switch between fiat and sats
                              TextField(
                                  controller: _amountControllerFiat,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: AppLocalizations.of(context)!
                                        .amountEuro,
                                  ),
                                ),
                          if (_selectedReceiveOption[0])
                            const SizedBox(height: 20),
                          if (_selectedReceiveOption[0])
                            TextField(
                              controller: _memoController,
                              maxLines: 4, //or null
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Memo',
                              ),
                            ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => {
                              if (_selectedReceiveOption[0])
                                {
                                  widget.onTopUpSats(
                                      SatoshiAmount.fromUnitAndValue(
                                          int.parse(_amountControllerSats.text),
                                          SatoshiUnit.sat),
                                      _memoController.text,
                                      widget.paymentMethods?[
                                          selectedPaymentMethod])
                                }
                              else
                                {
                                  widget.onTopUpFiat(
                                      int.parse(_amountControllerFiat.text))
                                }
                            },
                            child: _selectedReceiveOption[0]
                                ? Text(AppLocalizations.of(context)!
                                    .requestPayment)
                                : Text(
                                    AppLocalizations.of(context)!.chargeMoney),
                          ),
                        ])))));
  }
}
