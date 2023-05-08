import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'currency_display.dart';

class Balance extends StatefulWidget {
  const Balance(
      {super.key,
      required this.receiveOnTap,
      required this.sendOnTap,
      required this.balance});

  final void Function() receiveOnTap;
  final void Function() sendOnTap;
  final CurrencyDisplay balance;

  @override
  State<Balance> createState() => _BalanceState();
}

class _BalanceState extends State<Balance> {
  @override
  Widget build(BuildContext context) {
    // a widget that displays the balance and has two buttons to receive and send
    return Container(
      // black border, two sections, one for the balance, one for the buttons, border radius 25
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          // balance section
          Container(
            // black border, border radius 25, padding 10
            padding: const EdgeInsets.fromLTRB(16, 9, 0, 0),
            alignment: Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)!.balance,
                style: const TextStyle(fontSize: 20)),
          ),
          Container(
            // black border, border radius 25, padding 10
            padding: const EdgeInsets.fromLTRB(15, 0, 0, 7),
            child: widget.balance,
          ),
          // buttons section
          Container(
            // black border, border radius 25, padding 10
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.black,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // button without outline, black font
                // receive button
                Flexible(
                    child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.black,
                          width: 1,
                        ),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => widget.receiveOnTap(),
                      child: SizedBox(
                          height: 50,
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.receive,
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600),
                            ),
                          )),
                    ),
                  ),
                )),
                Flexible(
                    child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.black,
                            width: 1,
                          ),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => widget.sendOnTap(),
                        child: SizedBox(
                            height: 50,
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.send,
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600),
                              ),
                            )),
                      )),
                )),
              ],
            ),
          ),
          // box with border radius only on the bottom
        ],
      ),
    );
  }
}
