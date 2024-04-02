import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/heading.dart';
import 'package:id_ideal_wallet/basicUi/standard/invoice_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/basicUi/standard/top_up.dart';
import 'package:id_ideal_wallet/basicUi/standard/transaction_preview.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/payment_overview.dart';
import 'package:provider/provider.dart';

class PaymentCardOverview extends StatefulWidget {
  const PaymentCardOverview({super.key});

  @override
  PaymentCardOverviewState createState() => PaymentCardOverviewState();
}

class PaymentCardOverviewState extends State<PaymentCardOverview> {
  String currentSelection = '';
  bool adding = false;

  @override
  void initState() {
    super.initState();
    var w = Provider.of<WalletProvider>(context, listen: false);
    currentSelection =
        w.paymentCredentials.isEmpty ? '' : w.paymentCredentials.first.id ?? '';
  }

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
      VerifiableCredential toShow = wallet.paymentCredentials.firstWhere(
          (element) => element.id == currentSelection,
          orElse: () => VerifiableCredential(
              context: [credentialsV1Iri],
              type: [],
              issuer: '',
              credentialSubject: {},
              issuanceDate: DateTime.now()));

      List<Widget> content = [];
      content.add(Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 45,
              child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(navigatorKey.currentContext!).push(
                        MaterialPageRoute(
                          builder: (context) => TopUp(
                              paymentMethods: [toShow],
                              onTopUpSats: onTopUpSats,
                              onTopUpFiat: onTopUpFiat),
                        ),
                      ),
                  child: Text(AppLocalizations.of(context)!.receive)),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: SizedBox(
              height: 45,
              child: ElevatedButton(
                  onPressed: () =>
                      Provider.of<NavigationProvider>(context, listen: false)
                          .changePage([2]),
                  child: Text(AppLocalizations.of(context)!.send)),
            ),
          ),
        ],
      ));
      content.add(Heading(text: AppLocalizations.of(context)!.lastPayments));
      var lastPaymentData = wallet.lastPayments[currentSelection] ?? [];
      if (lastPaymentData.isNotEmpty) {
        var lastPayments = ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: wallet.lastPayments[currentSelection]?.length ?? 0,
            itemBuilder: (context, index) {
              return InkWell(
                child: TransactionPreview(
                    wide: true,
                    title: wallet
                        .lastPayments[currentSelection]![index].otherParty,
                    amount: CurrencyDisplay(
                        amount: wallet
                            .lastPayments[currentSelection]![index].action,
                        symbol: 'sat')),
                onTap: () {
                  if (wallet.lastPayments[currentSelection]![index]
                      .shownAttributes.isNotEmpty) {
                    var cred = wallet.getCredential(wallet
                        .lastPayments[currentSelection]![index]
                        .shownAttributes
                        .first);
                    if (cred != null && cred.w3cCredential.isNotEmpty) {
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
        content.add(lastPayments);
        if (wallet.getAllPayments(currentSelection).length > 3) {
          var additional = TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PaymentOverview(paymentContext: toShow))),
            child: Text(AppLocalizations.of(context)!.showMore,
                style: Theme.of(context).primaryTextTheme.titleMedium),
          );
          content.add(additional);
        }
      } else {
        var empty = TransactionPreview(
          title: AppLocalizations.of(context)!.noPayments,
          amount: const CurrencyDisplay(
            symbol: '',
            amount: '',
          ),
        );
        content.add(empty);
      }
      return StyledScaffoldTitle(
        useBackSwipe: false,
        title: wallet.paymentCredentials.isEmpty
            ? const Text('Zahlkarten')
            : DropdownButton(
                isExpanded: true,
                value: currentSelection,
                items: wallet.paymentCredentials
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(
                            e.credentialSubject['name'] ??
                                getTypeToShow(e.type),
                            maxLines: 2,
                          ),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  setState(() {
                    currentSelection = value!;
                  });
                },
              ),
        fab: wallet.paymentCredentials.isEmpty && !adding
            ? FloatingActionButton.extended(
                onPressed: () async {
                  setState(() {
                    adding = true;
                  });
                  var did = await wallet.newCredentialDid();
                  issueLNTestNetContext(
                      wallet,
                      {
                        "name": "Lightning Wallet",
                        "version": "1.4",
                        "description": "BTC Lightningcases",
                        "contexttype": "HidyContextLightning",
                        "mainbgimg":
                            "https://hidy.app/styles/hidycontextlnbtc_contextbg.png",
                        "overlaycolor": "#ffffff",
                        "backsidecolor": "#3a3a39",
                        "termsofserviceurl": "",
                        "services": [],
                        "vclayout": {}
                      },
                      isMainnet: true,
                      externalDid: did);

                  currentSelection = did;
                },
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.add))
            : null,
        child: wallet.paymentCredentials.isEmpty
            ? Center(
                child: adding
                    ? const CircularProgressIndicator()
                    : const Text('Keine Karten vorhanden'),
              )
            : Column(
                children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: ContextCard(
                          key: UniqueKey(),
                          //background: overallBackground,
                          context: toShow)
                      //)
                      ),
                  ...content
                ],
              ),
      );
    });
  }
}
