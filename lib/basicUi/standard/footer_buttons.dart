import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FooterButtons extends StatelessWidget {
  final String? positiveText, negativeText;
  final void Function()? negativeFunction, positiveFunction;

  const FooterButtons(
      {super.key,
      this.positiveText,
      this.negativeText,
      this.negativeFunction,
      this.positiveFunction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: positiveFunction ?? () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(45),
          ),
          child: Text(positiveText ?? AppLocalizations.of(context)!.accept),
        ),
        const SizedBox(
          height: 5,
        ),
        ElevatedButton(
          onPressed: negativeFunction ?? () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(45),
          ),
          child: Text(negativeText ?? AppLocalizations.of(context)!.reject),
        ),
      ],
    );
  }
}
