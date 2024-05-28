import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:id_ideal_wallet/constants/root_certificates.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:random_password_generator/random_password_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x509b/x509.dart' as x509;

Future<bool> isOnboard() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool? onboard = prefs.getBool('onboard');
  return onboard ?? false;
}

Future<bool> checkAuthSupport() {
  var auth = LocalAuthentication();
  return auth.isDeviceSupported();
}

Future<bool> openWallet(WalletStore wallet) async {
  try {
    if (!wallet.isWalletOpen()) {
      var messages = AndroidAuthMessages(
          signInTitle:
              AppLocalizations.of(navigatorKey.currentContext!)!.openWallet,
          cancelButton:
              AppLocalizations.of(navigatorKey.currentContext!)!.cancel,
          biometricHint:
              AppLocalizations.of(navigatorKey.currentContext!)!.verifyIdentity,
          goToSettingsButton:
              AppLocalizations.of(navigatorKey.currentContext!)!.openSettings,
          goToSettingsDescription:
              '${AppLocalizations.of(navigatorKey.currentContext!)!.technicNoteBad}\n${AppLocalizations.of(navigatorKey.currentContext!)!.noteGoToSettings}');
      var iosMessage = IOSAuthMessages(
        cancelButton: AppLocalizations.of(navigatorKey.currentContext!)!.cancel,
        goToSettingsButton:
            AppLocalizations.of(navigatorKey.currentContext!)!.openSettings,
        goToSettingsDescription:
            '${AppLocalizations.of(navigatorKey.currentContext!)!.technicNoteBad}\n${AppLocalizations.of(navigatorKey.currentContext!)!.noteGoToSettings}',
      );
      var auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      logger.d('device supported');
      var didAuthWork = false;

      didAuthWork = await auth.authenticate(
          localizedReason: AppLocalizations.of(navigatorKey.currentContext!)!
              .localizedReason,
          authMessages: [messages, iosMessage]);

      if (didAuthWork) {
        const storage = FlutterSecureStorage();
        String? pw = await storage.read(key: 'password');
        if (pw == null) {
          pw = RandomPasswordGenerator().randomPassword(
              letters: true,
              uppercase: true,
              numbers: true,
              specialChar: true,
              passwordLength: 20);
          await storage.write(key: 'password', value: pw);
        }
        await wallet.openBoxes(pw);
      } else {
        return false;
      }
    } else {
      return true;
    }
    return true;
  } catch (e) {
    logger.d(e);
    return false;
  }
}

Future<bool> verifyIssuerCert(x509.X509Certificate issuerCert) async {
  var certChain = await x509.buildCertificateChain(issuerCert, rootCerts);
  var verify = await x509.verifyCertificateChain(certChain);
  return verify;
}

String getTypeToShow(List<String> types) {
  return types.firstWhere(
      (element) =>
          element != 'VerifiableCredential' &&
          (!element.contains('HidyContext')),
      orElse: () => '');
}

void showScaffoldMessenger(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    duration: const Duration(seconds: 2),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(30.0),
      ),
    ),
    backgroundColor: Colors.black.withOpacity(0.6),
    behavior: SnackBarBehavior.floating,
    content: Text(message),
  ));
}

// source: https://stackoverflow.com/questions/50081213/how-do-i-use-hexadecimal-color-strings-in-flutter
extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
