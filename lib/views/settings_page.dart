import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/ausweis_view.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.settings,
      child: Column(
        children: [
          ListTile(
            title: Text(AppLocalizations.of(context)!.termsOfService),
            subtitle: Text(wallet.tosUrl),
            onTap: () {
              launchUrl(Uri.parse(wallet.tosUrl),
                  mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.license),
            onTap: () => Provider.of<NavigationProvider>(context, listen: false)
                .changePage([8]),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.settings),
            subtitle: Text(wallet.aboutUrl),
            onTap: () {
              launchUrl(Uri.parse(wallet.aboutUrl),
                  mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            title: const Text('Vertrauenswürdige Anwendungen'),
            onTap: () => Provider.of<NavigationProvider>(context, listen: false)
                .changePage([7]),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.newAppTitle),
            onTap: () => Provider.of<NavigationProvider>(context, listen: false)
                .changePage([9]),
          ),
          if (Platform.isAndroid)
            ListTile(
              title: Text('Ausweis'),
              onTap: () => Navigator.of(navigatorKey.currentContext!)
                  .push(MaterialPageRoute(builder: (context) => AusweisView())),
            )
        ],
      ),
    );
  }
}
