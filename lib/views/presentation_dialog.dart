import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/issuer_info.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';

Widget buildPresentationDialog(
    List<VerifiablePresentation> presentations, BuildContext context) {
  List<Widget> creds = [];
  for (var vp in presentations) {
    if (vp.verifiableCredential != null) {
      for (var vc in vp.verifiableCredential!) {
        creds.add(buildCredentialCard(vc));
      }
    }
  }
  return AlertDialog(
    title: Text('${AppLocalizations.of(context)!.noteShownCredentials}:'),
    content: SingleChildScrollView(
      child: Column(
        children: creds,
      ),
    ),
    actions: [
      TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Ok'))
    ],
  );
}

Card buildCredentialCard(VerifiableCredential credential) {
  List<Widget> content = [
    Text(getTypeToShow(credential.type),
        style:
            Theme.of(navigatorKey.currentContext!).primaryTextTheme.bodyMedium),
    const SizedBox(
      height: 10,
    )
  ];
  content.add(IssuerInfoText(issuer: credential.issuer));
  content.add(const SizedBox(
    height: 10,
  ));
  var additional = buildCredSubject(credential.credentialSubject);
  content += additional;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content,
      ),
    ),
  );
}
