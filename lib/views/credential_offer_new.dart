import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/basicUi/standard/receipt.dart';
import 'package:id_ideal_wallet/basicUi/standard/secured_widget.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';

class CredentialOfferDialogNew extends StatefulWidget {
  const CredentialOfferDialogNew(
      {super.key,
      required this.credentials,
      this.toPay,
      this.oidcIssuer,
      this.requestOidcTan = false,
      this.isOid = false});

  final List<VerifiableCredential> credentials;
  final String? toPay, oidcIssuer;
  final bool requestOidcTan, isOid;

  @override
  CredentialOfferDialogNewState createState() =>
      CredentialOfferDialogNewState();
}

class CredentialOfferDialogNewState extends State<CredentialOfferDialogNew> {
  final TextEditingController controller = TextEditingController();

  List<Widget> buildCredentialInfo() {
    var info = <Widget>[];
    for (var c in widget.credentials) {
      if (c.type.contains('PaymentReceipt')) continue;
      info.addAll([
        CredentialCard(
          credential: c,
          clickable: false,
        ),
        const SizedBox(
          height: 10,
        ),
        CredentialInfo(
          credential: c,
          showStatus: false,
        ),
        const SizedBox(
          height: 10,
        ),
      ]);
    }
    return info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SecuredWidget(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 0),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context)!.credentialOffer,
                    style: Theme.of(context).primaryTextTheme.headlineLarge,
                  ),
                  const SizedBox(height: 20),
                  ...buildCredentialInfo(),
                  if (widget.toPay != null)
                    Receipt(
                      title: AppLocalizations.of(context)!.invoice,
                      items: [
                        ReceiptItem(
                          label: "Credential",
                          amount: CurrencyDisplay(
                            amount: widget.toPay!,
                            symbol: "sat",
                          ),
                        ),
                      ],
                      total: ReceiptItem(
                        label: AppLocalizations.of(context)!.total,
                        amount: CurrencyDisplay(
                            amount: widget.toPay, symbol: "sat"),
                      ),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        if (widget.requestOidcTan)
          ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                AppLocalizations.of(context)!.oidcTan,
                style: Theme.of(context).primaryTextTheme.titleLarge,
              ),
              subtitle: Text(AppLocalizations.of(context)!.oidcTanInfo,
                  style: Theme.of(context).primaryTextTheme.titleMedium),
              children: [
                TextField(
                  onChanged: (text) {
                    controller.text = text;
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(width: 2, color: Colors.grey),
                    ),
                  ),
                  controller: controller,
                )
              ]),
        if (widget.requestOidcTan)
          const SizedBox(
            height: 5,
          ),
        FooterButtons(
            positiveText: widget.toPay != null
                ? AppLocalizations.of(context)!.orderWithPayment
                : AppLocalizations.of(context)!.accept,
            positiveFunction: () => Navigator.of(context)
                .pop(widget.requestOidcTan ? controller.text : true)),
      ],
    );
  }
}
