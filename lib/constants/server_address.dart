import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

var relay = 'http://167.235.195.132:8888';
//var relay = 'http://localhost:8888';
//var contextEndpoint =
//  'https://braceland.de/walletcontext?${Platform.isIOS ? '1' : '2'}';
var contextEndpoint =
    'https://test.hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
// var contextEndpoint =
//     'https://hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';

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
