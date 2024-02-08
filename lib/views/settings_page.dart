import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
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
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.settings,
      child: Column(
        children: [
          ListTile(
            title: Text(AppLocalizations.of(context)!.termsOfService),
            subtitle: Text(tosEndpoint),
            onTap: () {
              launchUrl(Uri.parse(tosEndpoint),
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
            subtitle: Text(
                'https://hidy.eu/${AppLocalizations.of(context)!.localeName}/app'),
            onTap: () {
              var locale = AppLocalizations.of(context)!.localeName;
              launchUrl(Uri.parse('https://hidy.eu/$locale/app'),
                  mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            title: const Text('Vertrauenswürdige Anwendungen'),
            onTap: () => Provider.of<NavigationProvider>(context, listen: false)
                .changePage([7]),
          )
        ],
      ),
    );
  }
}
