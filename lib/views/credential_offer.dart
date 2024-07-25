import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/basicUi/standard/issuer_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/secured_widget.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';

import '../basicUi/standard/receipt.dart';

class CredentialOfferDialog extends StatefulWidget {
  const CredentialOfferDialog(
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
  CredentialOfferDialogState createState() => CredentialOfferDialogState();
}

class CredentialOfferDialogState extends State<CredentialOfferDialog> {
  final TextEditingController controller = TextEditingController();

  List<Widget> buildContent() {
    List<Widget> contentData = [];

    for (var credential in widget.credentials) {
      var type = getTypeToShow(credential.type);
      if (type != 'PaymentReceipt' && type != 'PublicKeyCertificate') {
        var title = Text(
          type,
          style: Theme.of(context).primaryTextTheme.titleLarge,
        );
        contentData.add(
          const SizedBox(
            height: 10,
          ),
        );
        var subject = widget.isOid
            ? buildOidClaimsData(credential.credentialSubject)
            : buildCredSubject(credential.credentialSubject);
        VerifiableCredential? issuerCertCredential;
        try {
          issuerCertCredential = widget.credentials.firstWhere(
              (element) => element.type.contains('PublicKeyCertificate'));
        } catch (_) {}

        logger.d(issuerCertCredential?.toJson());
        contentData.add(
          ExpansionTile(
            title: title,
            initiallyExpanded: true,
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        MediaQuery.of(navigatorKey.currentContext!).size.width *
                            0.6,
                    child: IssuerInfoText(
                      issuer: issuerCertCredential ?? credential.issuer,
                      endpoint: widget.oidcIssuer,
                    ),
                  ),
                ),
                IssuerInfoIcon(
                  issuer: issuerCertCredential ?? credential.issuer,
                  endpoint: widget.oidcIssuer,
                )
              ],
            ),
            children: subject,
          ),
        );
      }
    }

    if (widget.requestOidcTan) {
      contentData.add(const SizedBox(
        height: 5,
      ));
      contentData.add(ExpansionTile(
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
          ),
          const SizedBox(
            height: 2,
          )
        ],
      ));
    }
    return contentData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SecuredWidget(
          child: SafeArea(
            child: Container(
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
                      style: Theme.of(context).primaryTextTheme.headlineLarge,
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      child: Column(
                        children: buildContent(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    widget.toPay != null
                        ? Receipt(
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
                        : const SizedBox(
                            height: 0,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
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

List<ListTile> buildOidClaimsData(Map<String, dynamic> claims) {
  List<ListTile> tiles = [];
  for (var k in claims.keys) {
    tiles.add(ListTile(
      title: Text(k),
      subtitle: Text(claims[k] ?? ''),
    ));
  }
  return tiles;
}
