import 'package:card_swiper/card_swiper.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/heading.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/basicUi/standard/invoice_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/top_up.dart';
import 'package:id_ideal_wallet/basicUi/standard/transaction_preview.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_overview.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:provider/provider.dart';

class SwiperView extends StatelessWidget {
  final SwiperController controller = SwiperController();

  SwiperView({super.key});

  void onTopUpSats(SatoshiAmount amount, String memo,
      VerifiableCredential? paymentCredential) async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var payType = wallet.getLnPaymentType(paymentCredential!.id!);
    logger.d(payType);
    try {
      var invoiceMap = await createInvoice(
          wallet.getLnInKey(paymentCredential.id!)!, amount,
          memo: memo, isMainnet: payType == 'mainnet');
      var index = invoiceMap['checking_id'];
      wallet.newPayment(paymentCredential.id!, index, memo, amount);
      showModalBottomSheet<dynamic>(
          useRootNavigator: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10)),
          ),
          context: navigatorKey.currentContext!,
          builder: (context) {
            return Consumer<WalletProvider>(builder: (context, wallet, child) {
              if (wallet.paymentTimer != null) {
                return InvoiceDisplay(
                  invoice: invoiceMap['payment_request'] ?? '',
                  amount: CurrencyDisplay(
                      amount: amount.toSat().toStringAsFixed(2),
                      symbol: 'sat',
                      mainFontSize: 35,
                      centered: true),
                  memo: memo,
                );
              } else {
                Future.delayed(
                    const Duration(seconds: 1),
                    () => Navigator.of(context)
                        .popUntil((route) => route.isFirst));
                return const SizedBox(
                  height: 10,
                );
              }
            });
          });
    } on LightningException catch (e) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.creationFailed,
          e.message);
    } catch (e) {
      showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.creationFailed,
      );
    }
  }

  void onTopUpFiat(int amount) {}

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      return SafeArea(
        child: Swiper(
          controller: controller,
          pagination:
              SwiperPagination(builder: CustomSwiperPaginationBuilder()),
          loop: false,
          viewportFraction: 0.87,
          scale: 0.875,
          itemCount: wallet.contextCredentials.length + 2,
          onTap: (indexOut) {
            if (indexOut == wallet.contextCredentials.length + 1) {
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
            if (indexOut != wallet.contextCredentials.length + 1 &&
                indexOut != 0) {
              var contextCred = wallet.contextCredentials[indexOut - 1];

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
                                initialUrl: btn['url']
                                    .toString()
                                    .replaceAll('wid=', 'wid=${wallet.lndwId}'),
                                title:
                                    btn['webViewTitle'] ?? btn['name'] ?? ''))),
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
                //Send and Receive
                buttons.add(Row(
                  children: [
                    Expanded(
                        child: SizedBox(
                            height: 45,
                            child: ElevatedButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) => TopUp(
                                            paymentMethods: [contextCred],
                                            onTopUpSats: onTopUpSats,
                                            onTopUpFiat: onTopUpFiat))),
                                child: Text(
                                    AppLocalizations.of(context)!.receive)))),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                        child: SizedBox(
                            height: 45,
                            child: ElevatedButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const QrScanner())),
                                child:
                                    Text(AppLocalizations.of(context)!.send)))),
                  ],
                ));
                // List of last three payments
                buttons.add(
                    Heading(text: AppLocalizations.of(context)!.lastPayments));
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
                                    builder: (context) => CredentialDetailView(
                                      credential: VerifiableCredential.fromJson(
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
                            style: Theme.of(context)
                                .primaryTextTheme
                                .titleMedium));
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

              if (contextCred.credentialSubject['contextId'] == '5') {
                buttons.add(SizedBox(
                    height: MediaQuery.of(context).size.height * 0.595,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.addCardExplanation,
                          style: Theme.of(context).primaryTextTheme.titleMedium,
                        ),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 45,
                          color: Colors.black54,
                        )
                      ],
                    )));
              }
            }

            String? overallBackground =
                indexOut != wallet.contextCredentials.length + 1 &&
                        indexOut != 0
                    ? wallet.contextCredentials[indexOut - 1]
                        .credentialSubject['backgroundImage']
                    : null;

            return SizedBox(
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                child: Column(children: [
                  // ConstrainedBox(
                  // constraints: BoxConstraints(
                  //     maxHeight: MediaQuery.of(context).size.height * 0.3),
                  // child:
                  indexOut == 0
                      ? wallet.getFavorites().isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(7),
                              child: Column(children: [
                                Text(
                                  textAlign: TextAlign.center,
                                  AppLocalizations.of(context)!.favorites,
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .headlineLarge,
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(AppLocalizations.of(context)!
                                    .favoriteExplanation)
                              ]))
                          : Wrap(children: [
                              Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      child: Text(
                                        textAlign: TextAlign.center,
                                        AppLocalizations.of(context)!.favorites,
                                        style: Theme.of(context)
                                            .primaryTextTheme
                                            .headlineLarge,
                                      ))),
                              for (int i = 0;
                                  i < wallet.contextCredentials.length;
                                  i++)
                                wallet.isFavorite(
                                        wallet.contextCredentials[i].id!)
                                    ? InkWell(
                                        onTap: () {
                                          logger.d('tap : $i');
                                          controller.move(i + 1);
                                        },
                                        child: Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.4,
                                                child: ContextCredentialCard(
                                                    borderWidth: 1,
                                                    edgeRadius: 10,
                                                    cardTitle: '',
                                                    cardTitleColor: wallet.contextCredentials[i].credentialSubject['overlaycolor'] !=
                                                            null
                                                        ? HexColor.fromHex(
                                                            wallet.contextCredentials[i].credentialSubject[
                                                                'overlaycolor'])
                                                        : const Color.fromARGB(
                                                            255, 255, 255, 255),
                                                    backgroundImage:
                                                        wallet.contextCredentials[i].credentialSubject['mainbgimg'] !=
                                                                null
                                                            ? Image.network(wallet.contextCredentials[i].credentialSubject['mainbgimg'])
                                                                .image
                                                            : null,
                                                    subjectName: wallet
                                                        .contextCredentials[i]
                                                        .credentialSubject['name'],
                                                    bottomLeftText: const SizedBox(
                                                      width: 0,
                                                    ),
                                                    bottomRightText: const SizedBox(
                                                      width: 0,
                                                    )))),
                                      )
                                    : const SizedBox(height: 0)
                            ])
                      : indexOut == wallet.contextCredentials.length + 1
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.5),
                              child: Column(children: [
                                const Padding(
                                    padding:
                                        EdgeInsets.only(top: 140, bottom: 20),
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.black54,
                                      size: 90,
                                    )),
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  AppLocalizations.of(context)!.addNewApp,
                                  style: Theme.of(context)
                                      .primaryTextTheme
                                      .titleMedium,
                                )
                              ]))
                          : //count == 1
                          //?
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: ContextCard(
                                  key: UniqueKey(),
                                  background: overallBackground,
                                  context:
                                      wallet.contextCredentials[indexOut - 1])
                              //)
                              ),
                  ...buttons
                ]),
              ),
            );
          },
        ),
      );
    });
  }
}

class CustomSwiperPaginationBuilder extends SwiperPlugin {
  final double space = 2.0;
  final Color activeColor = Colors.black26;
  final Color color = Colors.black12;
  final double activeSize = 12.0;
  final double size = 10.0;

  @override
  Widget build(BuildContext context, SwiperPluginConfig config) {
    final list = <Widget>[];

    final itemCount = config.itemCount - 2;
    final activeIndex = config.activeIndex;

    for (var i = 0; i < itemCount; ++i) {
      final active = i == activeIndex - 1;
      list.add(Container(
        key: Key('pagination_$i'),
        margin: EdgeInsets.all(space),
        child: ClipOval(
          child: Container(
            color: active ? activeColor : color,
            width: active ? activeSize : size,
            height: active ? activeSize : size,
          ),
        ),
      ));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () {
            config.controller.move(0);
          },
          child: Icon(
            Icons.star,
            color: config.activeIndex == 0 ? Colors.black26 : Colors.black12,
            size: 35,
          ),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Wrap(
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: list,
          ),
        ),
        InkWell(
          onTap: () {
            config.controller.move(config.itemCount - 1);
          },
          child: Icon(
            Icons.add_circle,
            color: config.activeIndex == config.itemCount - 1
                ? Colors.black26
                : Colors.black12,
            size: 35,
          ),
        )
      ],
    );
  }
}
