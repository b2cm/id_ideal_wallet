import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

class EnterPin extends StatefulWidget {
  const EnterPin({super.key});

  @override
  EnterPinState createState() => EnterPinState();
}

class EnterPinState extends State<EnterPin> {
  final controller = TextEditingController();
  var formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<AusweisProvider>(builder: (context, ausweis, child) {
      return Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              Text(
                'PIN-Eingabe',
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const Text('Bitte gib deine 6-stellige Ausweis-PIN ein:'),
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
                    maxLength: 6,
                    validator: (input) {
                      if (input == null || input.length != 6) {
                        return 'Die PIN muss genau 6 Stellen haben';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Ausweis-PIN',
                        suffixIcon: Icon(Icons.remove_red_eye_outlined)),
                  )),
              const SizedBox(
                height: 10,
              ),
              Text('Verbleibende Versuche: ${ausweis.pinRetry}'),
              if (ausweis.pinRetry == 2)
                Text(
                    'Solltest Du auch bei diesem Versuch eine falsche PIN eingeben, muss vor dem letzten Versuch die CAN eingegeben werden. Das ist die 6-stellige Zahlenfolge auf der Vorderseite deines Ausweises.'),
              if (ausweis.pinRetry == 1)
                Text(
                    'Das ist dein letzter Versuch, eine korrekte PIN einzugeben. Sollte auch dieser fehlschlagen, wird die Online-Ausweis-Funktion gesperrt.'),
              const SizedBox(
                height: 20,
              ),
              const Text(
                  'Du hast nur eine 5-stellige PIN? Dann brich den Vorgang bitte ab und nutze die Funktion "PIN ändern" der offiziellen Ausweis-App.')
            ],
          ),
        ),
        persistentFooterButtons: [
          FooterButtons(
            positiveFunction: () {
              if (formKey.currentState!.validate()) {
                ausweis.setPin(controller.text);
              }
            },
            negativeFunction: () => ausweis.cancel(),
          )
        ],
      );
    });
  }
}
