import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Widget buildPresentationProposalDialog(
    BuildContext context, PresentationDefinition definition) {
  List<Widget> proposedAttributes = [];
  for (var descriptor in definition.inputDescriptors) {
    if (descriptor.constraints?.fields != null) {
      for (var field in descriptor.constraints!.fields!) {
        var t = field.path.first.toString().substring(2);
        if (field.filter != null) {
          Map<String, dynamic> json = jsonDecode(field.filter!.toJson());
          if (json.containsKey('type') && json['type'] == 'string') {
            if (json['pattern'] != null) {
              t += ': ${json['pattern']}';
            }
          } else if (json.containsKey('type') && json['type'] == 'array') {
            Map<String, dynamic> contains = json['contains'] ?? {};
            if (contains.isNotEmpty) {
              if (contains['pattern'] != null) {
                t += ': ${contains['pattern']}';
              }
            }
          }
        }
        proposedAttributes.add(Text(t));
        proposedAttributes.add(const SizedBox(
          height: 7,
        ));
      }
    }
  }
  return AlertDialog(
    title: Text(AppLocalizations.of(context)!.noteOtherShowCredentials),
    content: Column(
      children: proposedAttributes,
    ),
    actions: [
      TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(AppLocalizations.of(context)!.ignore)),
      TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: Text(AppLocalizations.of(context)!.request))
    ],
  );
}
