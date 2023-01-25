import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/self_issuance.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
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
      onGenerateRoute: (args) {
        if (args.name != null && args.name!.contains('oob')) {
          handleDidcommMessage('https://wallet.id-ideal.de${args.name}');
        }
        return null;
      },
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  void onTopUpSats(int amount, String memo) async {}

  void onTopUpFiat(int amount) {}

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldName(
        name: 'Meine Credentials',
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
                      receiveOnTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => StyledScaffoldTitle(
                                  title: 'Zahlung anfordern',
                                  scanOnTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const QrScanner())),
                                  child: TopUp(
                                      // onTopUpSats: onTopUpSats,
                                      onTopUpSats: (x, y) {},
                                      onTopUpFiat: onTopUpFiat)))),
                      sendOnTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const QrScanner())),
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
              const Heading(text: 'Letzte Zahlungen'),
              Consumer<WalletProvider>(builder: (context, wallet, child) {
                if (wallet.lastPayments.isNotEmpty) {
                  return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: wallet.lastPayments.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          child: TransactionPreview(
                              title: wallet.lastPayments[index].otherParty,
                              amount: CurrencyDisplay(
                                  amount: wallet.lastPayments[index].action,
                                  symbol: '€')),
                          onTap: () {
                            if (wallet.lastPayments[index].shownAttributes
                                .isNotEmpty) {
                              var cred = wallet.getCredential(wallet
                                  .lastPayments[index].shownAttributes.first);
                              if (cred != null &&
                                  cred.w3cCredential.isNotEmpty) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => CredentialDetailView(
                                        credential:
                                            VerifiableCredential.fromJson(
                                                cred.w3cCredential))));
                              }
                            }
                          },
                        );
                      });
                } else {
                  return const TransactionPreview(
                      title: 'Keine getätigten Zahlungen',
                      amount: CurrencyDisplay(
                        symbol: '',
                        amount: '',
                      ));
                }
              }),
              TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const PaymentOverview())),
                  child: const Text('Weitere anzeigen',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ))),
              const Heading(text: "Zeitlich relevant"),
              Shortcut(
                  onTap: () => logger.d("tapped shortcut"),
                  icon: const AssetImage("assets/truck-fast-regular.png"),
                  text: "Zwei Pakete kommen heute an"),
              Container(
                height: 12,
              ),
              Shortcut(
                  onTap: () => logger.d("tapped shortcut"),
                  icon: const AssetImage("assets/ticket-regular.png"),
                  text:
                      "Ticket for hello hello hello hello hello hello darkness my old friend"),
              const Heading(text: "Hub"),
              GridView.count(
                  // disable scrolling
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  // no spacing
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 0,
                  // shrink the grid to fit the content
                  shrinkWrap: true,
                  // children: a list of hub-apps
                  children: [
                    HubApp(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SelfIssueList())),
                        icon:
                            const AssetImage("assets/house-crack-regular.png"),
                        label: "Selbstausstellung"),
                    HubApp(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const WebViewWindow(
                                    title: 'Ausstell-Service',
                                    initialUrl: 'http://localhost:8081'))),
                        icon: const AssetImage("assets/plane-regular.png"),
                        label: "Credential ausstellen"),
                    HubApp(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const WebViewWindow(
                                    title: 'Ticket-Shop',
                                    initialUrl:
                                        'https://167.235.195.132:8082'))),
                        icon: const AssetImage("assets/ticket-regular.png"),
                        label: "Tickets"),
                    HubApp(
                        onTap: () => logger.d("tapped hub app"),
                        icon: const AssetImage("assets/print-regular.png"),
                        label: "Drucken"),
                  ]),
            ],
          ),
        ));
  }
}
