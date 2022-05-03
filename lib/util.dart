import 'package:dart_ssi/wallet.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/auth_strings.dart';
import 'package:local_auth/local_auth.dart';
import 'package:random_password_generator/random_password_generator.dart';

Future<bool> openWallet(WalletStore wallet) async {
  if (!wallet.isWalletOpen()) {
    print('try open');
    var messages = const AndroidAuthMessages(
        signInTitle: 'Wallet öffnen',
        cancelButton: 'Abbrechen',
        biometricHint: 'Verifizieren Sie Ihre Identität');
    var auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    print('device supported');
    var didAuthWork = await auth.authenticate(
        localizedReason:
            'Zum Öffnen des Wallets ist Ihre Authentifizierung nötig',
        androidAuthStrings: messages);
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
}
