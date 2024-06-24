import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

class EnterPuk extends StatefulWidget {
  const EnterPuk({super.key});

  @override
  EnterPukState createState() => EnterPukState();
}

class EnterPukState extends State<EnterPuk> {
  final controller = TextEditingController();
  var formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Text(
              'PUK-Eingabe',
              style: Theme.of(context).primaryTextTheme.headlineLarge,
            ),
            const Text('Bitte gib die 10-stellige PUK deines Ausweises ein:'),
            const SizedBox(
              height: 10,
            ),
            Form(
                key: formKey,
                child: TextFormField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  controller: controller,
                  maxLength: 10,
                  validator: (input) {
                    if (input == null || input.length != 10) {
                      return 'Die PUK muss genau 10 Stellen haben';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'PUK',
                      suffixIcon: Icon(Icons.remove_red_eye_outlined)),
                )),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
      ),
      persistentFooterButtons: [
        FooterButtons(
          positiveFunction: () {
            if (formKey.currentState!.validate()) {
              Provider.of<AusweisProvider>(context, listen: false)
                  .setPuk(controller.text);
            }
          },
          negativeFunction: () =>
              Provider.of<AusweisProvider>(context, listen: false).cancel(),
        )
      ],
    );
  }
}
