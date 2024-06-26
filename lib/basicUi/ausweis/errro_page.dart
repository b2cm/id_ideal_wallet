import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AusweisProvider>(builder: (context, ausweis, child) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              Text(
                'Vorgang fehlgeschlagen',
                style: Theme.of(context).primaryTextTheme.headlineLarge,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                ausweis.errorDescription,
                style: Theme.of(context).primaryTextTheme.titleLarge,
              ),
              const SizedBox(
                height: 10,
              ),
              Text(ausweis.errorMessage)
            ],
          ),
        ),
        persistentFooterButtons: [
          ElevatedButton(
              onPressed: () =>
                  Provider.of<AusweisProvider>(context, listen: false).reset(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
              ),
              child: const Text('Ok')),
        ],
      );
    });
  }
}
