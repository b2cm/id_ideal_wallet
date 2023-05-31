import 'package:dart_ssi/didcomm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';

import 'receipt.dart';

class CredentialOfferDialog extends StatelessWidget {
  const CredentialOfferDialog({
    super.key,
    required this.credentials,
    this.toPay,
  });

  final List<LdProofVcDetail> credentials;
  final String? toPay;

  List<Widget> buildContent() {
    List<Widget> contentData = [];

    for (var d in credentials) {
      var credential = d.credential;
      var type = credential.type
          .firstWhere((element) => element != 'VerifiableCredential');
      if (type != 'PaymentReceipt') {
        var title = Text(
          type,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        );
        contentData.add(
          const SizedBox(
            height: 10,
          ),
        );
        var subject = buildCredSubject(credential.credentialSubject);

        contentData.add(
          ExpansionTile(
            title: title,
            initiallyExpanded: true,
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IssuerInfoText(issuer: credential.issuer),
                ),
                IssuerInfoIcon(issuer: credential.issuer)
              ],
            ),
            children: subject,
          ),
        );
      }
    }
    return contentData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:
            // rounded corners on the top
            Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Padding(
            // padding only left and right
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.credentialOffer,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Column(
                  children: buildContent(),
                ),
                const SizedBox(height: 20),
                toPay != null
                    ? Receipt(
                        title: AppLocalizations.of(context)!.invoice,
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
                          label: AppLocalizations.of(context)!.total,
                          amount: CurrencyDisplay(amount: toPay, symbol: "€"),
                        ),
                      )
                    : const SizedBox(
                        height: 0,
                      ),
              ],
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        Column(
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(45),
              ),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            const SizedBox(
              height: 5,
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                minimumSize: const Size.fromHeight(45),
              ),
              child: toPay != null
                  ? Text(AppLocalizations.of(context)!.orderWithPayment)
                  : const Text("Ok"),
            )
          ],
        )
      ],
    );
  }
}
