import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logger/logger.dart';

var relay = 'https://167.235.195.132:8888';
//var relay = 'http://localhost:8888';

// *****Endpoints for Public release*****
//
// var contextEndpoint =
//     'https://hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
// var applicationEndpoint =
//     'https://hidy.app/walletcontext/apps?plattform=${Platform.isIOS ? '1' : '2'}';
// var stylingEndpoint = 'https://hidy.app/walletcontext/layouts';
// var termsVersionEndpoint = 'https://hidy.app/walletcontext/terms';
// String versionNumber = '2.4.10';
// String baseUrl = 'https://hidy.app';
// bool testBuild = false;

// ******Endpoints for Test-Release******

var contextEndpoint =
    'https://test.hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
var applicationEndpoint =
    'https://test.hidy.app/walletcontext/apps?plattform=${Platform.isIOS ? '1' : '2'}';
var stylingEndpoint = 'https://test.hidy.app/walletcontext/layouts';
var termsVersionEndpoint = 'https://test.hidy.app/walletcontext/terms';
String versionNumber = '2.4.12-test';
String baseUrl = 'https://test.hidy.app';
bool testBuild = true;

var tosEndpoint =
    'https://hidy.eu/${AppLocalizations.of(navigatorKey.currentContext!)!.localeName}/terms';

var lnTestNetEndpoint = 'https://testpayments.pixeldev.eu';
var lnMainnetEndpoint = 'https://payments.pixeldev.eu';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

var logger = Logger();

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
