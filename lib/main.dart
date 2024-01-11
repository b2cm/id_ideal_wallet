import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/theme.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_card_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/settings_page.dart';
import 'package:id_ideal_wallet/views/swiper_view.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:id_ideal_wallet/views/welcome_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  if (testBuild) {
    HttpOverrides.global = DevHttpOverrides();
  }
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  bool isInit = await isOnboard();
  runApp(ChangeNotifierProvider(
    create: (context) => WalletProvider(appDocumentDir.path, isInit),
    child: const App(),
  ));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(context) {
    var idWalletDesignTheme = IdWalletDesignTheme();
    return MaterialApp(
      theme: idWalletDesignTheme.theme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
      ],
      navigatorKey: navigatorKey,
      home: const StartScreen(),
      onUnknownRoute: (args) =>
          MaterialPageRoute(builder: (context) => const StartScreen()),
      onGenerateRoute: (args) {
        if (!Provider.of<WalletProvider>(context, listen: false).onboard) {
          return null;
        }
        logger.d(args);
        if (args.name != null && args.name!.contains('oob')) {
          handleDidcommMessage('https://wallet.bccm.dev${args.name}');
        } else if (args.name != null && args.name!.contains('webview')) {
          logger.d(args);
          var asUri = Uri.parse('https://wallet.bccm.dev${args.name}');
          logger.d(asUri);
          logger.d(asUri.queryParameters);
          var uriToCall =
              '${Uri.parse(asUri.queryParameters['url']!)}${asUri.hasFragment ? '#${asUri.fragment}' : ''}';
          logger.d(uriToCall);

          // var newQuery = {'wid': wallet.lndwId};
          // newQuery.addAll(uriToCall.queryParameters);
          // var newUriToCall = uriToCall.replace(queryParameters: newQuery);
          // logger.d(newUriToCall);
          return MaterialPageRoute(
              builder: (context) =>
                  Consumer<WalletProvider>(builder: (context, wallet, child) {
                    if (wallet.isOpen()) {
                      logger.d(uriToCall);
                      return WebViewWindow(
                          initialUrl: uriToCall
                              .toString()
                              .replaceAll('wid=', 'wid=${wallet.lndwId}'),
                          title: asUri.queryParameters['title'] ?? '');
                    } else {
                      return const Scaffold(
                        body: SafeArea(
                            child: Center(
                          child: CircularProgressIndicator(),
                        )),
                      );
                    }
                  }));
        } else if (args.name != null && args.name!.contains('invoice')) {
          var uri = Uri.parse('https://wallet.bccm.dev${args.name}');
          var invoice = uri.queryParameters['invoice'];
          if (invoice != null) {
            payInvoiceInteraction(invoice,
                isMainnet: invoice.toLowerCase().startsWith('lnbc'));
          } else if (uri.queryParameters.containsKey('lnurl')) {
            handleLnurl(uri.queryParameters['lnurl']!);
          }
        }
        return null;
      },
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  StartScreenState createState() => StartScreenState();
}

class StartScreenState extends State<StartScreen> {
  bool init = true;
  bool showWelcome = false;

  @override
  initState() {
    super.initState();
    checkOnboard();
  }

  Future<void> checkOnboard() async {
    var on = await isOnboard();
    logger.d(on);
    showWelcome = !on;
    init = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return init
        ? const Scaffold(
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
        : showWelcome
            ? const WelcomeScreen()
            : const HomeScreen();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        return Scaffold(
          body: Stack(children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 10, right: 10, bottom: 5),
                  child: Image(
                    image: const AssetImage('assets/images/stempel.png'),
                    width: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? MediaQuery.of(context).size.width
                        : null,
                    height: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? MediaQuery.of(context).size.height
                        : null,
                    fit: BoxFit.fill,
                  ),
                )
              ],
            ),
            SwiperView(),
          ]),
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black,
            showUnselectedLabels: true,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.co_present), label: 'Credentials'),
              BottomNavigationBarItem(
                  icon: const Icon(
                    Icons.qr_code_scanner_sharp,
                    //size: 30,
                  ),
                  label: AppLocalizations.of(context)!.scan),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.settings),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.credit_card), label: 'Zahlung'),
            ],
            currentIndex: 1,
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const CredentialPage(
                            initialSelection: 'all',
                          )));
                  break;
                case 1:
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const QrScanner()));
                  break;
                case 2:
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const SettingsPage()));
                  break;
                case 3:
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const PaymentCardOverview()));
                  break;
              }
            },
          ),
        );
      } else if (wallet.openError) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text(AppLocalizations.of(context)!.errorOpen),
              ),
            ),
          ),
        );
      } else {
        wallet.openWallet();
        return const Scaffold(
            body: SafeArea(
                child: Center(
          child: CircularProgressIndicator(),
        )));
      }
    });
  }
}
