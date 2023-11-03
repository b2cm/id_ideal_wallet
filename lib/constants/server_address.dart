import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logger/logger.dart';

var relay = 'https://167.235.195.132:8888';
//var relay = 'http://localhost:8888';

// *****Endpoints for Public release*****

var contextEndpoint =
    'https://hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
var termsVersionEndpoint = 'https://hidy.app/walletcontext/terms';
String versionNumber = '2.1.1';
String baseUrl = 'https://hidy.app';

// ******Endpoints for Test-Release******

// var contextEndpoint =
//     'https://test.hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
// var termsVersionEndpoint = 'https://test.hidy.app/walletcontext/terms';
// String versionNumber = '2.0.8-test';
// String baseUrl = 'https://test.hidy.app';

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
