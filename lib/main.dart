import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/custom_navigation_item.dart';
import 'package:id_ideal_wallet/basicUi/standard/theme.dart';
import 'package:id_ideal_wallet/basicUi/standard/top_up.dart';
import 'package:id_ideal_wallet/constants/firebase_options.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/notification_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/abo_overview.dart';
import 'package:id_ideal_wallet/views/ausweis_view.dart';
import 'package:id_ideal_wallet/views/authorized_apps.dart';
import 'package:id_ideal_wallet/views/backup_view.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/identity_overview.dart';
import 'package:id_ideal_wallet/views/mail_credential_view.dart';
import 'package:id_ideal_wallet/views/payment_card_overview.dart';
import 'package:id_ideal_wallet/views/payment_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/search_new_abo.dart';
import 'package:id_ideal_wallet/views/send_satoshi_screen.dart';
import 'package:id_ideal_wallet/views/settings_page.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:id_ideal_wallet/views/welcome_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  var storage = await SharedPreferences.getInstance();
  var storedMessages = storage.getString('messages');
  Map messagesJson = storedMessages == null ? {} : jsonDecode(storedMessages);
  messagesJson[message.messageId] =
      SimplifiedNotification.fromRemoteMessage(message).toJson();
  storage.setString('messages', jsonEncode(messagesJson));
  logger.d(storage.getString('messages'));
  logger.d("Handling a background message: ${message.messageId}");
}

void main() async {
  if (testBuild) {
    HttpOverrides.global = DevHttpOverrides();
  }
  WidgetsFlutterBinding.ensureInitialized();
  bool withFirebase = true;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    withFirebase = false;
  }

  final appDocumentDir = await getApplicationDocumentsDirectory();
  bool isInit = await isOnboard();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
          create: (context) =>
              WalletProvider(appDocumentDir.path, withFirebase, isInit)),
      ChangeNotifierProvider(create: (context) => NavigationProvider(!isInit)),
      ChangeNotifierProvider(create: (context) => MdocProvider()),
      ChangeNotifierProvider(create: (context) => AusweisProvider()),
    ],
    child: const App(),
  ));

  // prevent ml-kit to call home (used in mobile scanner)
  // source: https://github.com/juliansteenbakker/mobile_scanner/issues/553#issuecomment-1691387214
  if (Platform.isAndroid) {
    final path = appDocumentDir.parent.path;
    final file =
        File('$path/databases/com.google.android.datatransport.events');
    await file.writeAsString('Fake');
  }
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
        Locale('en'),
        Locale('de'),
      ],
      navigatorKey: navigatorKey,
      home: const StartScreen(),
      onUnknownRoute: (args) =>
          MaterialPageRoute(builder: (context) => const StartScreen()),
      onGenerateRoute: (args) {
        Provider.of<NavigationProvider>(context, listen: false)
            .handleLink('https://wallet.bccm.dev${args.name}');
        logger.d(args);
        return null;
      },
    );
  }
}

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(builder: (context, navigator, child) {
      return navigator.showWelcome ? const WelcomeScreen() : const HomeScreen();
    });
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
                    activeIndices: const [NavigationPage.abo],
                    navigator: navigator),
                CustomNavigationItem(
                    // text: 'Identität',
                    text: 'Credentials',
                    activeIcon: Icons.co_present,
                    inactiveIcon: Icons.co_present_outlined,
                    activeIndices: const [
                      // NavigationPage.identityOverview,
                      NavigationPage.credential,
                      NavigationPage.credentialDetail,
                      NavigationPage.email
                    ],
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
                    text: AppLocalizations.of(context)!.backup,
                    activeIcon: Icons.backup,
                    inactiveIcon: Icons.backup_outlined,
                    activeIndices: const [
                      NavigationPage.backupOverview,
                      NavigationPage.backupCreate,
                      NavigationPage.backupRestore
                    ],
                    navigator: navigator),
                CustomNavigationItem(
                    text: AppLocalizations.of(context)!.settings,
                    activeIcon: Icons.settings,
                    inactiveIcon: Icons.settings_outlined,
                    activeIndices: const [
                      NavigationPage.settings,
                      NavigationPage.authorizedApps,
                      NavigationPage.license,
                      NavigationPage.searchNewAbo,
                      NavigationPage.ausweis
                    ],
                    navigator: navigator),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget buildFab1(NavigationProvider navigator) {
    return Visibility(
      visible:
          MediaQuery.of(navigatorKey.currentContext!).viewInsets.bottom == 0.0,
      child: SizedBox(
        height: 75,
        width: 75,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {
              navigator.changePage([
                NavigationPage.qrScanner,
                NavigationPage.sendSatoshi,
                NavigationPage.topUp
              ]);
            },
            backgroundColor: Colors.grey.shade300,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.qr_code_scanner,
            ),
          ),
        ),
      ),
    );
  }

  Widget getContent(NavigationProvider navigator, WalletProvider wallet) {
    switch (navigator.activeIndex) {
      case NavigationPage.abo:
        return const AboOverview();
      case NavigationPage.credential:
        return const CredentialPage(initialSelection: 'all');
      case NavigationPage.qrScanner:
        return const QrScanner();
      case NavigationPage.paymentCard:
        return const PaymentCardOverview();
      case NavigationPage.settings:
        return const SettingsPage();
      case NavigationPage.webView:
        return WebViewWindow(initialUrl: navigator.webViewUrl, title: '');
      case NavigationPage.credentialDetail:
        return CredentialDetailView(credential: navigator.credential!);
      case NavigationPage.authorizedApps:
        return const AuthorizedAppsManger();
      case NavigationPage.license:
        return LicensePage(
          applicationName: 'Hidy',
          applicationVersion: versionNumber,
          applicationIcon: Image.asset(
            'assets/icons/app_icon-playstore.png',
            height: 100,
          ),
        );
      case NavigationPage.searchNewAbo:
        return const SearchNewAbo();
      case NavigationPage.sendSatoshi:
        return const SendSatoshiScreen();
      case NavigationPage.topUp:
        return TopUp(paymentMethod: navigator.credential);
      case NavigationPage.paymentOverview:
        return PaymentOverview(paymentContext: navigator.credential!);
      case NavigationPage.ausweis:
        return const AusweisView();
      case NavigationPage.backupOverview:
        return const BackupOverview();
      case NavigationPage.backupCreate:
        return const BackupWidget();
      case NavigationPage.backupRestore:
        return const RestoreWidget();
      case NavigationPage.identityOverview:
        return const IdentityOverview();
      case NavigationPage.email:
        return const MailCredentialView();
      default:
        return const AboOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        // TODO: DOUBLE CHECK POSITION!!!!
        // loginOneSignal(wallet);
        return Consumer<NavigationProvider>(
            builder: (context, navigator, child) {
          Widget content = getContent(navigator, wallet);

          // Only add the swipe gesture on iOS
          if (Platform.isIOS) {
            content = GestureDetector(
              onHorizontalDragUpdate: (details) {
                // Detect right swipe from the left edge
                if (details.delta.dx > 0 && details.globalPosition.dx < 50) {
                  navigator.goBack();
                }
              },
              child: content,
            );
          }
          return PopScope(
              canPop: navigator.canPop,
              onPopInvokedWithResult: (_, a) => navigator.goBack(),
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
                    Center(
                      child: LifecycleWatcher(),
                    ),
                    if (wallet.issuanceRunning.isNotEmpty)
                      Center(
                        child: Card(
                          color: Colors.grey.shade300,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 40,
                            height: MediaQuery.of(context).size.height / 4,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!
                                        .pictureProcess,
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    AppLocalizations.of(context)!
                                        .pictureProcessNote,
                                    style: Theme.of(context)
                                        .primaryTextTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  const CircularProgressIndicator()
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
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
        return Scaffold(
          body: SafeArea(
            child: Stack(children: [
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
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.2,
                  ),
                  Image.asset(
                    'assets/images/HidyLogoNoBack.png',
                    height: 150,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.1,
                  ),
                  Text(AppLocalizations.of(context)!.pictureProcessNote),
                  const SizedBox(
                    width: double.infinity,
                    height: 5,
                  ),
                  Text(AppLocalizations.of(context)!.prepareWallet),
                ],
              )
            ]),
          ),
        );
      }
    });
  }
}

class LifecycleWatcher extends StatefulWidget {
  const LifecycleWatcher({super.key});

  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    logger.d('new state: ${state.name}');
    if (state == AppLifecycleState.resumed) {
      var storage = await SharedPreferences.getInstance();
      await storage.reload();
      logger.d(storage.getKeys());
      var storedMessages = storage.getString('messages');
      logger.d('stored messages: $storedMessages ');
      if (storedMessages != null) {
        Map messagesJson = jsonDecode(storedMessages);

        Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
            .onNewMessages(messagesJson.values
                .map((e) => SimplifiedNotification.fromJson(e))
                .toList());

        storage.remove('messages');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox();
  }
}
