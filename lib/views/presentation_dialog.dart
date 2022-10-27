import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';

import 'credential_detail.dart';

Widget buildPresentationDialog(
    List<VerifiablePresentation> presentations, BuildContext context) {
  List<Widget> creds = [];
  for (var vp in presentations) {
    for (var vc in vp.verifiableCredential) {
      creds.add(buildCredentialCard(vc));
    }
  }
  return AlertDialog(
    title: const Text('Diese Credentials wurden soeben vorgezeigt:'),
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
