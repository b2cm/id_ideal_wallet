import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
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
              onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Hidy',
                  applicationVersion: versionNumber,
                  applicationIcon: Image.asset(
                    'assets/icons/app_icon-playstore.png',
                    height: 100,
                  ),
                  useRootNavigator: true),
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
          ],
        ));
  }
}
