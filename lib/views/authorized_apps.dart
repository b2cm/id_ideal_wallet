import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../basicUi/standard/styled_scaffold_title.dart';
import '../provider/wallet_provider.dart';

class AuthorizedAppsManger extends StatefulWidget {
  const AuthorizedAppsManger({super.key});

  @override
  AuthorizedAppsMangerState createState() => AuthorizedAppsMangerState();
}

class AuthorizedAppsMangerState extends State<AuthorizedAppsManger> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      return StyledScaffoldTitle(
        useBackSwipe: false,
        title: const Text('Vertrauenswürdige Apps'),
        child: ListView.builder(
            itemCount: wallet.getAuthorizedApps().length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(wallet.getAuthorizedApps()[index]),
                trailing: InkWell(
                    onTap: () {
                      wallet.deleteAuthorizedApp(
                          wallet.getAuthorizedApps()[index]);
                    },
                    child: const Icon(Icons.delete)),
              );
            }),
      );
    });
  }
}

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({super.key});

  @override
  TextInputDialogState createState() => TextInputDialogState();
}

class TextInputDialogState extends State<TextInputDialog> {
  var controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      //insetPadding: EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Vertrauenswürde App hinzufügen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 10,
            ),
            TextField(
              controller: controller,
              onChanged: (text) {
                controller.text = text;
                setState(() {});
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(width: 2, color: Colors.grey),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(null);
                    },
                    child: const Text('Abbrechen')),
                const SizedBox(
                  width: 5,
                ),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(controller.text);
                    },
                    child: const Text('Hinzufügen'))
              ],
            )
          ],
        ),
      ),
    );
  }
}
