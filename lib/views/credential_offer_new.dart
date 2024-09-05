import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/secured_widget.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SecuredWidget(
          child: SafeArea(
            child: Container(),
          ),
        ),
      ),
    );
  }
}
