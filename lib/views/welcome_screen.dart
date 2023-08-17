import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool techOk = false;
  bool dataImprintCheck = false;
  bool load = true;
  bool versionLoad = false;
  bool error = false;
  String version = '1.0.0';

  @override
  void initState() {
    super.initState();
    checkTech();
  }

  Future<void> checkTech() async {
    techOk = Platform.isAndroid ? await checkAuthSupport() : true;
    load = false;
    setState(() {});
    var res = await get(Uri.parse(termsVersionEndpoint));
    if (res.statusCode == 200) {
      var json = jsonDecode(res.body);
      version = json['version'];
    }
    versionLoad = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 5),
                child: Image(
                  image: const AssetImage('assets/images/stempel.png'),
                  width:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? MediaQuery.of(context).size.width
                          : null,
                  height: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? MediaQuery.of(context).size.height
                      : null,
                  fit: BoxFit.fill,
                ),
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    AppLocalizations.of(context)!.welcome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 40),
                  )),
              const SizedBox(
                height: 20,
              ),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(AppLocalizations.of(context)!.welcomeNote)),
              Platform.isAndroid
                  ? ListTile(
                      leading: Icon(
                        load
                            ? Icons.refresh
                            : techOk
                                ? Icons.check
                                : Icons.close,
                        size: 45,
                        color: load
                            ? Colors.grey
                            : techOk
                                ? Colors.greenAccent.shade700
                                : Colors.redAccent,
                      ),
                      isThreeLine: true,
                      title: Text(AppLocalizations.of(context)!.technic),
                      subtitle: Column(
                        children: [
                          Text(techOk
                              ? AppLocalizations.of(context)!.technicNoteOk
                              : AppLocalizations.of(context)!.technicNoteBad),
                          techOk
                              ? const SizedBox(
                                  height: 0,
                                )
                              : Row(
                                  children: [
                                    TextButton(
                                        onPressed: () =>
                                            AppSettings.openAppSettings(
                                                type: Platform.isAndroid
                                                    ? AppSettingsType
                                                        .lockAndPassword
                                                    : AppSettingsType.settings),
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .openSettings)),
                                    TextButton(
                                        onPressed: checkTech,
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .recheck))
                                  ],
                                )
                        ],
                      ),
                    )
                  : const SizedBox(
                      height: 0,
                    ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 6),
                  shape: error
                      ? RoundedRectangleBorder(
                          side: BorderSide(color: Colors.red))
                      : null,
                  leading: Checkbox(
                      value: dataImprintCheck,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            dataImprintCheck = newValue;
                          });
                        }
                      }),
                  title: Text(AppLocalizations.of(context)!.termsOfService),
                  subtitle: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                            text: AppLocalizations.of(context)!
                                .termsOfServiceNote1),
                        TextSpan(
                            text: tosEndpoint,
                            style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse(tosEndpoint),
                                    mode: LaunchMode.externalApplication);
                              }),
                        TextSpan(
                            text: AppLocalizations.of(context)!
                                .termsOfServiceNote2)
                      ],
                    ),
                  ),
                ),
              )
            ],
          )
        ]),
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: techOk && dataImprintCheck && versionLoad
              ? () async {
                  await checkTech();
                  if (techOk && dataImprintCheck) {
                    final SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    await prefs.setBool('onboard', true);
                    await prefs.setString('tosVersion', version);
                    Provider.of<WalletProvider>(navigatorKey.currentContext!,
                            listen: false)
                        .onBoarded();
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => HomeScreen()));
                  }
                }
              : () {
                  error = true;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: const Duration(seconds: 3),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(30.0),
                      ),
                    ),
                    backgroundColor: Colors.black.withOpacity(0.6),
                    behavior: SnackBarBehavior.floating,
                    content: Text(AppLocalizations.of(context)!.pleaseAccept),
                  ));
                  setState(() {});
                },
          child: Text(AppLocalizations.of(context)!.start,
              style: TextStyle(
                  color: techOk && dataImprintCheck && versionLoad
                      ? Colors.blue
                      : Colors.grey)),
        )
      ],
    );
  }
}
