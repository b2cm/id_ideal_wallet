import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';

class AmountSelection extends StatefulWidget {
  final int minAmount, maxAmount;
  final String description;

  const AmountSelection(
      {super.key,
      required this.minAmount,
      required this.maxAmount,
      required this.description});

  @override
  AmountSelectionState createState() => AmountSelectionState();
}

class AmountSelectionState extends State<AmountSelection> {
  final _formKey = GlobalKey<FormState>();
  int selectedValue = 0;
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedValue = widget.minAmount;
    controller.text = widget.minAmount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context)!.enterAmount,
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                '${AppLocalizations.of(context)!.description}: ${widget.description}',
                style: Theme.of(context).primaryTextTheme.titleLarge,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                '${AppLocalizations.of(context)!.amount}: ${widget.minAmount} - ${widget.maxAmount} mSat',
                style: Theme.of(context).primaryTextTheme.bodySmall,
              ),
              const SizedBox(
                height: 20,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                    child: TextFormField(
                  controller: controller,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onEditingComplete: () {
                    if (int.parse(controller.text) <= widget.minAmount) {
                      setState(() {
                        selectedValue = widget.minAmount;
                        controller.text = widget.minAmount.toString();
                        FocusManager.instance.primaryFocus?.unfocus();
                      });
                    } else if (int.parse(controller.text) >= widget.minAmount &&
                        int.parse(controller.text) <= widget.maxAmount) {
                      setState(() {
                        selectedValue = int.parse(controller.text);
                        FocusManager.instance.primaryFocus?.unfocus();
                      });
                    } else {
                      setState(() {
                        selectedValue = widget.maxAmount;
                        controller.text = widget.maxAmount.toString();
                        FocusManager.instance.primaryFocus?.unfocus();
                      });
                    }
                  },
                )),
                const SizedBox(
                  width: 10,
                ),
                const Text('mSat'),
                const SizedBox(
                  width: 10,
                ),
              ])
            ],
          ),
        )),
        persistentFooterButtons: [
          FooterButtons(
            positiveFunction: () =>
                Navigator.of(context).pop(selectedValue.toInt()),
            negativeFunction: () => Navigator.of(context).pop(null),
            positiveText: 'Ok',
          )
        ]);
  }
}

// Source: https://www.appsloveworld.com/flutter/100/38/flutter-text-field-allow-user-to-insertion-of-a-number-within-a-given-range-only
class LimitRange extends TextInputFormatter {
  LimitRange(
    this.minRange,
    this.maxRange,
  ) : assert(
          minRange < maxRange,
        );

  final int minRange;
  final int maxRange;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var value = int.parse(newValue.text);
    if (value < minRange) {
      return TextEditingValue(text: minRange.toString());
    } else if (value > maxRange) {
      return TextEditingValue(text: maxRange.toString());
    }
    return newValue;
  }
}
