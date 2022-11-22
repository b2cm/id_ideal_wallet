import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';
import 'package:id_wallet_design/id_wallet_design.dart';

Widget buildOfferCredentialDialog(
    BuildContext context, List<LdProofVcDetail> credentials, String? toPay) {
  VerifiableCredential? paymentReceipt;

  List<Widget> contentData = [];

  for (var d in credentials) {
    var credential = d.credential;
    var type = credential.type
        .firstWhere((element) => element != 'VerifiableCredential');
    if (type != 'PaymentReceipt') {
      var title = Text(type,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
      contentData.add(const SizedBox(
        height: 10,
      ));
      var subject = buildCredSubject(credential.credentialSubject);

      contentData.add(ExpansionTile(
        title: title,
        subtitle: Row(
          children: [
            IssuerInfoText(issuer: credential.issuer),
            IssuerInfoIcon(issuer: credential.issuer)
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
        children: subject,
      ));
    } else {
      paymentReceipt = credential;
    }
  }

  return SafeArea(
      child: Material(
          child:
              // rounded corners on the top
              Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Padding(
                      // padding only left and right
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CredentialOfferDialog(
                        credential: Column(
                          children: contentData,
                        ),
                        receipt: paymentReceipt != null
                            ? Receipt(
                                items: [
                                    ReceiptItem(
                                      label: "Credential",
                                      amount: CurrencyDisplay(
                                        amount: toPay!,
                                        symbol: "€",
                                      ),
                                    ),
                                  ],
                                total: ReceiptItem(
                                    label: "Gesamt",
                                    amount: CurrencyDisplay(
                                        amount: toPay, symbol: "€")))
                            : null,
                      )))));
}
