import 'dart:io';

import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  HttpOverrides.global = DevHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  runApp(ChangeNotifierProvider(
    create: (context) => WalletProvider(appDocumentDir.path),
    child: const App(),
  ));
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    var idWalletDesignTheme = IdWalletDesignTheme();
    return MaterialApp(
      theme: idWalletDesignTheme.theme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffold(
        name: 'Max Mustermann',
        nameOnTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CredentialPage())),
        scanOnTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const QrScanner())),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Consumer<WalletProvider>(builder: (context, wallet, child) {
                if (wallet.isOpen()) {
                  return Balance(
                      receiveOnTap: () {},
                      sendOnTap: () {},
                      balance: CurrencyDisplay(
                        amount: wallet.balance.toString(),
                        symbol: '€',
                        mainFontSize: 40,
                      ));
                } else {
                  wallet.openWallet();
                  return Balance(
                      receiveOnTap: () {},
                      sendOnTap: () {},
                      balance: const CurrencyDisplay(
                        amount: 'wird geladen',
                        symbol: '€',
                      ));
                }
              }),
              const SizedBox(
                height: 10,
              ),
              Consumer<WalletProvider>(builder: (context, wallet, child) {
                if (wallet.lastPayments.isNotEmpty) {
                  return ListView.builder(
                      shrinkWrap: true,
                      itemCount: wallet.lastPayments.length,
                      itemBuilder: (context, index) {
                        return TransactionPreview(
                            title: wallet.lastPayments[index].otherParty,
                            amount: CurrencyDisplay(
                                amount: wallet.lastPayments[index].action,
                                symbol: '€'));
                      });
                } else {
                  return const TransactionPreview(
                      title: 'Keine getätigten Zahlungen',
                      amount: CurrencyDisplay(
                        symbol: '',
                        amount: '',
                      ));
                }
              })
            ],
          ),
        ));
  }
}
