import 'dart:io';

import 'package:card_swiper/card_swiper.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/heading.dart';
import 'package:id_ideal_wallet/basicUi/standard/theme.dart';
import 'package:id_ideal_wallet/basicUi/standard/transaction_preview.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
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
      home: const MainPage(),
      onGenerateRoute: (args) {
        logger.d(args.name);
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
                          initialUrl:
                              '$uriToCall${uriToCall.toString().contains('?') ? '&' : '?'}wid=${wallet.lndwId}',
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
        }
        return null;
      },
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
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
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fill,
                  ),
                )
              ],
            ),
            Swiper(
              loop: false,
              viewportFraction: 0.87,
              scale: 0.875,
              itemCount: wallet.contextCredentials.length + 1,
              onTap: (indexOut) {
                if (indexOut == wallet.contextCredentials.length) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const AddContextCredential()));
                }
              },
              itemBuilder: (context, indexOut) {
                // var count = indexOut == wallet.contextCredentials.length
                //     ? -1
                //     : wallet
                //             .getCredentialsForContext(
                //                 wallet.contextCredentials[indexOut].id!)
                //             .length +
                //         1;

                var buttons = <Widget>[];
                if (indexOut != wallet.contextCredentials.length) {
                  var contextCred = wallet.contextCredentials[indexOut];

                  // Normal context credential -> only list of Buttons
                  List b = contextCred.credentialSubject['buttons'] ??
                      contextCred.credentialSubject['services'] ??
                      [];
                  for (var btn in b) {
                    buttons.add(
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => WebViewWindow(
                                    initialUrl:
                                        '${btn['url']!}?wid=${wallet.lndwId}',
                                    title: btn['webViewTitle'] ??
                                        btn['name'] ??
                                        ''))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btn['backgroundColor'] != null
                              ? HexColor.fromHex(btn['backgroundColor'])
                              : null,
                          minimumSize: const Size.fromHeight(50), // NEW
                        ),
                        child: Text(btn['buttonText'] ?? btn['name']),
                      ),
                    );

                    buttons.add(const SizedBox(
                      height: 15,
                    ));
                  }

                  // Payment Credential
                  if (contextCred.type.contains('PaymentContext')) {
                    // List of last three payments
                    buttons.add(Heading(
                        text: AppLocalizations.of(context)!.lastPayments));
                    var lastPaymentData =
                        wallet.lastPayments[contextCred.id!] ?? [];
                    if (lastPaymentData.isNotEmpty) {
                      var lastPayments = ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount:
                              wallet.lastPayments[contextCred.id!]?.length ?? 0,
                          itemBuilder: (context, index) {
                            return InkWell(
                              child: TransactionPreview(
                                  wide: true,
                                  title: wallet
                                      .lastPayments[contextCred.id!]![index]
                                      .otherParty,
                                  amount: CurrencyDisplay(
                                      amount: wallet
                                          .lastPayments[contextCred.id!]![index]
                                          .action,
                                      symbol: 'sat')),
                              onTap: () {
                                if (wallet.lastPayments[contextCred.id!]![index]
                                    .shownAttributes.isNotEmpty) {
                                  var cred = wallet.getCredential(wallet
                                      .lastPayments[contextCred.id!]![index]
                                      .shownAttributes
                                      .first);
                                  if (cred != null &&
                                      cred.w3cCredential.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CredentialDetailView(
                                          credential:
                                              VerifiableCredential.fromJson(
                                                  cred.w3cCredential),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          });
                      buttons.add(lastPayments);
                      if (wallet.getAllPayments(contextCred.id!).length > 3) {
                        var additional = TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => PaymentOverview(
                                        paymentContext: contextCred))),
                            child: Text(AppLocalizations.of(context)!.showMore,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                )));
                        buttons.add(additional);
                      }
                    } else {
                      var empty = TransactionPreview(
                        title: AppLocalizations.of(context)!.noPayments,
                        amount: const CurrencyDisplay(
                          symbol: '',
                          amount: '',
                        ),
                      );
                      buttons.add(empty);
                    }
                  }
                }

                String? overallBackground =
                    indexOut != wallet.contextCredentials.length
                        ? wallet.contextCredentials[indexOut]
                            .credentialSubject['backgroundImage']
                        : null;

                return SingleChildScrollView(
                    child: Column(children: [
                  // ConstrainedBox(
                  // constraints: BoxConstraints(
                  //     maxHeight: MediaQuery.of(context).size.height * 0.3),
                  // child:
                  indexOut == wallet.contextCredentials.length
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.3),
                          child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 140),
                              child: Icon(
                                Icons.add,
                                color: Colors.grey,
                                size: 90,
                              )))
                      : //count == 1
                      //?
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: ContextCard(
                              background: overallBackground,
                              context: wallet.contextCredentials[indexOut])
                          //)
                          ),
                  // : Swiper(
                  //     loop: true,
                  //     allowImplicitScrolling: false,
                  //     itemCount: count,
                  //     scrollDirection: Axis.vertical,
                  //     axisDirection: AxisDirection.left,
                  //     curve: Curves.fastOutSlowIn,
                  //     viewportFraction: 0.8,
                  //     scale: 0.95,
                  //     itemBuilder: (context, index) =>
                  //         CredentialCard(
                  //             background: overallBackground,
                  //             credential: index == 0
                  //                 ? wallet
                  //                     .contextCredentials[indexOut]
                  //                 : wallet.credentials[index - 1]),
                  //     layout: SwiperLayout.TINDER,
                  //     customLayoutOption: CustomLayoutOption(
                  //         startIndex: -1, stateCount: 5)
                  //       ..addRotate([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
                  //       ..addOpacity([1.0, 1.0, 1.0, 0.0, 0.0, 0.0])
                  //       ..addScale(
                  //           [0.95, 0.95, 0.95, 0.9, 0.9, 0.8, 0.8],
                  //           Alignment.bottomLeft)
                  //       ..addTranslate([
                  //         const Offset(-5, -5),
                  //         const Offset(0, 0),
                  //         const Offset(5, 5),
                  //         const Offset(20, 50),
                  //         const Offset(30, 100),
                  //         const Offset(40, 50),
                  //       ]),
                  //     containerHeight:
                  //         MediaQuery.of(context).size.width * 0.6,
                  //     itemHeight:
                  //         MediaQuery.of(context).size.width * 0.54,
                  //     itemWidth:
                  //         MediaQuery.of(context).size.width * 0.95,
                  //   )),
                  ...buttons
                ]));
              },
            ),
          ])),
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.co_present), label: 'Credentials'),
              BottomNavigationBarItem(
                  icon: const Icon(
                    Icons.qr_code_scanner_sharp,
                    size: 30,
                  ),
                  label: AppLocalizations.of(context)!.scan),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.settings),
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
                  var locale = AppLocalizations.of(context)!.localeName;
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => WebViewWindow(
                          initialUrl: 'https://hidy.eu/$locale/app',
                          title: 'About')));
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
        ))));
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

// source: https://stackoverflow.com/questions/50081213/how-do-i-use-hexadecimal-color-strings-in-flutter
extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
