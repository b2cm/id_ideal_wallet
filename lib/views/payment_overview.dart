import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/basicUi/standard/transaction_preview.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class PaymentOverview extends StatelessWidget {
  final VerifiableCredential paymentContext;

  const PaymentOverview({super.key, required this.paymentContext});

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: AppLocalizations.of(context)!.payments(1),
        child: Consumer<WalletProvider>(
          builder: (context, wallet, child) {
            var allPayments = wallet.getAllPayments(paymentContext.id!);
            return ListView.builder(
                itemCount: allPayments.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    child: TransactionPreview(
                        wide: true,
                        title: allPayments[index].otherParty,
                        amount: CurrencyDisplay(
                            amount: allPayments[index].action, symbol: 'sat')),
                    onTap: () {
                      if (allPayments[index].shownAttributes.isNotEmpty) {
                        var cred = wallet.getCredential(
                            allPayments[index].shownAttributes.first);
                        if (cred != null && cred.w3cCredential.isNotEmpty) {
                          Provider.of<NavigationProvider>(context,
                                  listen: false)
                              .changePage([
                            NavigationPage.credentialDetail,
                            NavigationPage.paymentOverview
                          ],
                                  credential: VerifiableCredential.fromJson(
                                      cred.w3cCredential));
                        }
                      }
                    },
                  );
                });
          },
        ));
  }
}
