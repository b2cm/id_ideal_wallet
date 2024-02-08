import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/custom_navigation_item.dart';
import 'package:id_ideal_wallet/basicUi/standard/theme.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/abo_overview.dart';
import 'package:id_ideal_wallet/views/authorized_apps.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_card_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/search_new_abo.dart';
import 'package:id_ideal_wallet/views/settings_page.dart';
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
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
          create: (context) => WalletProvider(appDocumentDir.path, isInit)),
      ChangeNotifierProvider(create: (context) => NavigationProvider())
    ],
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
        if (args.name != null && args.name!.contains('ooburl')) {
          handleOobUrl('https://wallet.bccm.dev${args.name}');
        } else if (args.name != null && args.name!.contains('oob')) {
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
                          ),
                        ),
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

  BottomAppBar buildBottomBar1(
      BuildContext context, NavigationProvider navigator) {
    return BottomAppBar(
      surfaceTintColor: Colors.grey,
      shape: const CircularNotchedRectangle(),
      notchMargin: 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CustomNavigationItem(
                    text: 'Home',
                    activeIcon: Icons.home,
                    inactiveIcon: Icons.home_outlined,
                    activeIndices: const [0, 9],
                    navigator: navigator),
                CustomNavigationItem(
                    text: 'Credentials',
                    activeIcon: Icons.co_present,
                    inactiveIcon: Icons.co_present_outlined,
                    activeIndices: const [1, 6],
                    navigator: navigator),
                const SizedBox(
                  width: 20,
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const SizedBox(
                  width: 20,
                ),
                CustomNavigationItem(
                    text: AppLocalizations.of(context)!.payments(0),
                    activeIcon: Icons.credit_card,
                    inactiveIcon: Icons.credit_card_outlined,
                    activeIndices: const [3],
                    navigator: navigator),
                CustomNavigationItem(
                    text: AppLocalizations.of(context)!.settings,
                    activeIcon: Icons.settings,
                    inactiveIcon: Icons.settings_outlined,
                    activeIndices: const [4, 7, 8],
                    navigator: navigator),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildFab1(NavigationProvider navigator) {
    return SizedBox(
      height: 75,
      width: 75,
      child: FittedBox(
        child: FloatingActionButton(
          onPressed: () {
            navigator.changePage([2]);
          },
          backgroundColor: Colors.grey.shade300,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.qr_code_scanner,
          ),
        ),
      ),
    );
  }

  Widget getContent(NavigationProvider navigator, WalletProvider wallet) {
    switch (navigator.activeIndex) {
      case 0:
        return const AboOverview();
      case 1:
        return const CredentialPage(initialSelection: 'all');
      case 2:
        return const QrScanner();
      case 3:
        return const PaymentCardOverview();
      case 4:
        return const SettingsPage();
      case 5:
        return WebViewWindow(initialUrl: navigator.webViewUrl, title: '');
      case 6:
        return CredentialDetailView(credential: navigator.credential!);
      case 7:
        return const AuthorizedAppsManger();
      case 8:
        return LicensePage(
          applicationName: 'Hidy',
          applicationVersion: versionNumber,
          applicationIcon: Image.asset(
            'assets/icons/app_icon-playstore.png',
            height: 100,
          ),
        );
      case 9:
        return const SearchNewAbo();
      default:
        return const AboOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        return Consumer<NavigationProvider>(
            builder: (context, navigator, child) {
          return PopScope(
              canPop: navigator.canPop,
              onPopInvoked: (_) => navigator.goBack(),
              child: Scaffold(
                  body: Stack(children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, bottom: 5),
                          child: Image(
                            image:
                                const AssetImage('assets/images/stempel.png'),
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
                    getContent(navigator, wallet),
                  ]),
                  bottomNavigationBar: buildBottomBar1(context, navigator),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: buildFab1(navigator)));
        });
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
            ),
          ),
        );
      }
    });
  }
}
