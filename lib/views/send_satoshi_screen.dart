import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:provider/provider.dart';

class SendSatoshiScreen extends StatefulWidget {
  const SendSatoshiScreen({super.key});

  @override
  SendSatoshiScreenState createState() => SendSatoshiScreenState();
}

class SendSatoshiScreenState extends State<SendSatoshiScreen> {
  var controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.sendSatoshi,
              style: Theme.of(context).primaryTextTheme.headlineLarge,
            ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Invoice',
                ),
                maxLines: 10,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Provider.of<NavigationProvider>(context, listen: false)
                        .goBack();
                    payInvoiceInteraction(controller.text,
                        isMainnet:
                            controller.text.toLowerCase().startsWith('lnbc'));
                  }
                },
                child: Text(AppLocalizations.of(context)!.send))
          ],
        ),
      ),
    );
  }
}
