import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/invoice_display.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class TopUp extends StatefulWidget {
  const TopUp({super.key, this.paymentMethod});

  final VerifiableCredential? paymentMethod;

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

  void onTopUpSats(SatoshiAmount amount, String memo,
      VerifiableCredential? paymentCredential) async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var payType = wallet.getLnPaymentType(paymentCredential!.id!);
    logger.d(payType);
    try {
      var invoiceMap = await createInvoice(
          wallet.getLnInKey(paymentCredential.id!)!, amount,
          memo: memo, isMainnet: payType == 'mainnet');
      var index = invoiceMap['checking_id'];
      wallet.newPayment(paymentCredential.id!, index, memo, amount);
      showModalBottomSheet<dynamic>(
          useRootNavigator: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10)),
          ),
          context: navigatorKey.currentContext!,
          builder: (context) {
            return Consumer<WalletProvider>(builder: (context, wallet, child) {
              if (wallet.paymentTimer != null) {
                return InvoiceDisplay(
                  invoice: invoiceMap['payment_request'] ?? '',
                  amount: CurrencyDisplay(
                      amount: amount.toSat().toStringAsFixed(2),
                      symbol: 'sat',
                      mainFontSize: 35,
                      centered: true),
                  memo: memo,
                );
              } else {
                Future.delayed(const Duration(seconds: 1), () {
                  Navigator.pop(context);
                  Provider.of<NavigationProvider>(context, listen: false)
                      .changePage([3, 11]);
                });
                return const SizedBox(
                  height: 10,
                );
              }
            });
          });
    } on LightningException catch (e) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.creationFailed,
          e.message);
    } catch (e) {
      showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.creationFailed,
      );
    }
  }

  void onTopUpFiat(int amount) {}

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
                          widget.paymentMethod == null
                              ? const SizedBox(
                                  height: 0,
                                )
                              : Text(
                                  AppLocalizations.of(context)!.requestPayment,
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .headlineLarge),
                          widget.paymentMethod == null
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
                              : const SizedBox(),
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
                                  onTopUpSats(
                                      SatoshiAmount.fromUnitAndValue(
                                          int.parse(_amountControllerSats.text),
                                          SatoshiUnit.sat),
                                      _memoController.text,
                                      widget.paymentMethod)
                                }
                              else
                                {
                                  onTopUpFiat(
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
