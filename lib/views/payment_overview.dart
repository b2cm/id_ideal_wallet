import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:provider/provider.dart';

class PaymentOverview extends StatelessWidget {
  const PaymentOverview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'Zahlungen',
        scanOnTap: () {},
        child: Consumer<WalletProvider>(
          builder: (context, wallet, child) {
            var allPayments = wallet.getAllPayments();
            return ListView.builder(
                itemCount: allPayments.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    child: TransactionPreview(
                        title: allPayments[index].otherParty,
                        amount: CurrencyDisplay(
                            amount: allPayments[index].action, symbol: '€')),
                    onTap: () {
                      if (allPayments[index].shownAttributes.isNotEmpty) {
                        var cred = wallet.getCredential(
                            allPayments[index].shownAttributes.first);
                        if (cred != null && cred.w3cCredential.isNotEmpty) {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => CredentialDetailView(
                                  credential: VerifiableCredential.fromJson(
                                      cred.w3cCredential))));
                        }
                      }
                    },
                  );
                });
          },
        ));
  }
}
