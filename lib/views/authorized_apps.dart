import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../basicUi/standard/styled_scaffold_title.dart';
import '../provider/wallet_provider.dart';

class AuthorizedAppsManger extends StatelessWidget {
  const AuthorizedAppsManger({super.key});

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
