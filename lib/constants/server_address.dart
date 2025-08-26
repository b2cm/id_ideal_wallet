import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/digests/sha256.dart';

import '../l10n/app_localizations.dart';

var relay = 'https://167.235.195.132:8888';
//var relay = 'http://localhost:8888';
const String isoPrefix = 'isoData';
const String sdPrefix = 'sdJwt';

Map knownAuthServer = {
  'https://issuer.eudiw.dev/oidc': {
    "client_id": "ISnuvPs-TJ3gCd8Q-80lTA",
    "registration_access_token": "POI-r-KmNkqNlvfWR3V-y4vJlQYLsf6vEhELR0VuikE",
    "registration_client_uri":
        "https://issuer.eudiw.dev:5000/oidc/registration_api?client_id=ISnuvPs-TJ3gCd8Q-80lTA",
    "client_id_issued_at": 1716545689,
    "client_secret": "0be48cbe6b567fdddf3f706785283fe134a872b28548ccb7bd0fc716",
    "client_secret_expires_at": 1719137689,
    "application_type": "native",
    "response_types": ["code"],
    "grant_types": ["authorization_code"],
    "subject_type": "public",
    "id_token_signed_response_alg": "ES256",
    "userinfo_signed_response_alg": "ES256",
    "request_object_signing_alg": "ES256",
    "token_endpoint_auth_method": "public",
    "token_endpoint_auth_signing_alg": "ES256",
    "default_max_age": 86400,
    "response_modes": ["fragment", "form_post", "query"],
    "redirect_uri": "https://wallet.bccm.dev/redirect"
  },
  'https://auth.eudiw.dev/realms/pid-issuer-realm': {
    'client_id': 'wallet-dev',
    'redirect_uri': 'eudi-openid4ci://authorize'
  },
  'http://localhost:8080/realms/test-realm': {
    'client_id': 'hidy',
    'redirect_uri': "https://wallet.bccm.dev/redirect"
  },
  'http://localhost:8080/realms/pid-issuer-realm': {
    'client_id': 'wallet-dev',
    'redirect_uri': "eudi-openid4ci://authorize"
  },
  'https://authenticate.eudiw.dev/realms/pid-issuer-realm': {
    'client_id': 'wallet-dev',
    'redirect_uri': 'eudi-openid4ci://authorize'
  },
  // 'https://id.staging.authada.de/eudi/issuer/pid': {
  //   'client_id': 'eEWA Wallet',
  //   'redirect_uri': 'eudi-issuance://authorization'
  // },
  'https://localhost:4443/idp/realms/pid-issuer-realm': {
    'client_id': 'wallet-dev',
    'redirect_uri': 'eudi-openid4ci://authorize'
  },
  'https://demo.pid-issuer.bundesdruckerei.de/c': {
    'client_id': 'fed79862-af36-4fee-8e64-89e3c91091ed',
    'pidIssuer': true,
    'dpop': true
  },
  'https://demo.pid-issuer.bundesdruckerei.de/c2': {
    'client_id': 'fed79862-af36-4fee-8e64-89e3c91091ed',
    'pidIssuer': true,
    'dpop': true
  },
  'https://demo.pid-issuer.bundesdruckerei.de/c1': {
    'client_id': 'fed79862-af36-4fee-8e64-89e3c91091ed',
    'pidIssuer': true,
    'dpop': true
  }
};

// *****Endpoints for Public release*****

// var contextEndpoint =
//     'https://hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
// var applicationEndpoint =
//     'https://hidy.app/walletcontext/apps?plattform=${Platform.isIOS ? '1' : '2'}';
// var stylingEndpoint = 'https://hidy.app/walletcontext/layouts';
// var termsVersionEndpoint = 'https://hidy.app/walletcontext/terms';
// var messagingBackend =
//     'https://test.hidy.app/walletcontext/fbm/registeraccount';
// String versionNumber = '4.0.8';
// String baseUrl = 'https://hidy.app';
// bool testBuild = false;

// ******Endpoints for Test-Release******

var contextEndpoint =
    'https://test.hidy.app/walletcontext?plattform=${Platform.isIOS ? '1' : '2'}';
var applicationEndpoint =
    'https://test.hidy.app/walletcontext/apps?plattform=${Platform.isIOS ? '1' : '2'}';
var stylingEndpoint = 'https://test.hidy.app/walletcontext/layouts';
var termsVersionEndpoint = 'https://test.hidy.app/walletcontext/terms';
var messagingBackend =
    'https://test.hidy.app/walletcontext/fbm/registeraccount';
String versionNumber = '4.2.2-test';
String baseUrl = 'https://test.hidy.app';
bool testBuild = true;

bool inOidcTest = false;

var tosEndpoint =
    'https://hidy.eu/${AppLocalizations.of(navigatorKey.currentContext!)!.localeName}/terms';

var lnMainnetEndpoint = 'https://payments.pixeldev.eu';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

var logger = Logger();
const double bottomPadding = 30;

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

final sha256 = SHA256Digest();
