import 'dart:async';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/constants/property_names.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:json_schema/json_schema.dart';
import 'package:provider/provider.dart';

class IssuanceInfo extends StatefulWidget {
  final PresentationDefinition definition;
  final List<String> descriptorIds;

  const IssuanceInfo(
      {super.key, required this.definition, required this.descriptorIds});

  @override
  IssuanceInfoState createState() => IssuanceInfoState();
}

class IssuanceInfoState extends State<IssuanceInfo> {
  Widget information = Text(
      AppLocalizations.of(navigatorKey.currentContext!)!.issuanceInfoNotFound);
  Set<String> types = {};

  @override
  void initState() {
    super.initState();

    for (var descriptorId in widget.descriptorIds) {
      var descriptor = widget.definition.inputDescriptors
          .firstWhere((element) => element.id == descriptorId);

      if (descriptor.constraints != null &&
          descriptor.constraints?.fields != null) {
        for (var field in descriptor.constraints!.fields!) {
          for (var path in field.path) {
            var pathString = path.toString();
            if (pathString.contains('type')) {
              if (field.filter?.type == SchemaType.array &&
                  field.filter?.contains != null) {
                if (field.filter!.contains!.constValue is String) {
                  types.add(field.filter!.contains!.constValue);
                }
                if (field.filter!.contains!.pattern != null) {
                  types.add(field.filter!.contains!.pattern!.pattern);
                }
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var layouts =
        Provider.of<WalletProvider>(context, listen: false).credentialStyling;

    List<Widget> buttons = [];

    for (var type in types) {
      var layout = layouts[type];
      if (layout != null && layout['issuerUrl'] != null) {
        buttons.add(ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              var nav = Provider.of<NavigationProvider>(context, listen: false);
              nav.redirectWebViewUrl = nav.webViewUrl;
              nav.changePage([NavigationPage.credential], track: false);
              Timer(
                  const Duration(milliseconds: 5),
                  () => navigateClassic(WebViewWindow(
                      initialUrl: layout['issuerUrl']!,
                      title: 'Aussteller-Info')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
            ),
            child: Text(propertyNames[type] ?? type)));
      }
    }

    if (buttons.isNotEmpty) {
      information = Column(
        children: [
          Text(AppLocalizations.of(context)!.issuanceInfoFound),
          ...buttons
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: information,
      ),
    );
  }
}
