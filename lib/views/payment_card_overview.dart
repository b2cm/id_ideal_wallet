import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/heading.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/basicUi/standard/transaction_preview.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
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

  @override
  void initState() {
    super.initState();
    var w = Provider.of<WalletProvider>(context, listen: false);
    currentSelection =
        w.paymentCredentials.isEmpty ? '' : w.paymentCredentials.first.id ?? '';
  }

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
                  builder: (context) =>
                      PaymentOverview(paymentContext: toShow))),
              child: Text(AppLocalizations.of(context)!.showMore,
                  style: Theme.of(context).primaryTextTheme.titleMedium));
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
        child: wallet.paymentCredentials.isEmpty
            ? Column(
                children: [
                  const Text('Keine Karten vorhanden'),
                  ElevatedButton(
                      onPressed: () {},
                      child: Text(AppLocalizations.of(context)!.add))
                ],
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
