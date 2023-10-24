import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/issuer_info.dart';

import 'receipt.dart';

class CredentialOfferDialog extends StatelessWidget {
  const CredentialOfferDialog({
    super.key,
    required this.credentials,
    this.toPay,
  });

  final List<VerifiableCredential> credentials;
  final String? toPay;

  List<Widget> buildContent() {
    List<Widget> contentData = [];

    for (var credential in credentials) {
      var type = getTypeToShow(credential.type);
      if (type != 'PaymentReceipt' && type != 'PublicKeyCertificate') {
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
        VerifiableCredential? issuerCertCredential;
        try {
          issuerCertCredential = credentials.firstWhere(
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
                  child: IssuerInfoText(
                      issuer: issuerCertCredential ?? credential.issuer),
                ),
                IssuerInfoIcon(
                    issuer: issuerCertCredential ?? credential.issuer)
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
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      child: Column(
                        children: buildContent(),
                      ),
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
                              amount:
                                  CurrencyDisplay(amount: toPay, symbol: "€"),
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
            positiveText: toPay != null
                ? AppLocalizations.of(context)!.orderWithPayment
                : AppLocalizations.of(context)!.accept),
      ],
    );
  }
}

class FooterButtons extends StatelessWidget {
  final String? positiveText, negativeText;
  final void Function()? negativeFunction, positiveFunction;

  const FooterButtons(
      {super.key,
      this.positiveText,
      this.negativeText,
      this.negativeFunction,
      this.positiveFunction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: positiveFunction ?? () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            minimumSize: const Size.fromHeight(45),
          ),
          child: Text(positiveText ?? AppLocalizations.of(context)!.accept),
        ),
        const SizedBox(
          height: 5,
        ),
        ElevatedButton(
          onPressed: negativeFunction ?? () => Navigator.of(context).pop(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            minimumSize: const Size.fromHeight(45),
          ),
          child: Text(negativeText ?? AppLocalizations.of(context)!.reject),
        ),
      ],
    );
  }
}

class SecuredWidget extends StatefulWidget {
  final Widget child;

  const SecuredWidget({
    super.key,
    required this.child,
  });

  @override
  SecuredWidgetState createState() => SecuredWidgetState();
}

class SecuredWidgetState extends State<SecuredWidget> {
  DateTime? currentBackPressTime;

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(30.0),
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.6),
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.cancelWarning),
      ));
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(onWillPop: onWillPop, child: widget.child);
  }
}
