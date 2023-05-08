import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'credential_detail.dart';

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
