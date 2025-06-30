import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/root_certificates.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:keystore_plugin/keystore_plugin.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:provider/provider.dart'; //import 'package:random_password_generator/random_password_generator.dart';
import 'package:sd_jwt/sd_jwt.dart' as sd_jwt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:x509b/x509.dart' as x509;

import '../l10n/app_localizations.dart';

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

Future<bool> isOnboard() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool? onboard = prefs.getBool('onboard');
  return onboard ?? false;
}

Future<bool> checkAuthSupport() {
  var auth = LocalAuthentication();
  return auth.isDeviceSupported();
}

Future<bool> openWallet(WalletStore wallet, bool newUser) async {
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
        // iOS do not delete keychain items on uninstall, so delete old passwords
        if (newUser) {
          logger.d('new install');
          pw = null;
          await storage.delete(key: 'password');
        }
        if (pw == null) {
          pw = hexEncode(getSecureRandom().nextBytes(20));
          await storage.write(key: 'password', value: pw);
        }
        logger.d('pw: $pw');
        var s = DateTime.now();
        await wallet.openBoxes(
            password: pw,
            keyStorage: Platform.isAndroid
                ? {
                    'software':
                        SoftwareKeyStoreBackend(pw, await getNameExpansion()),
                    'system': OsKeyStore(),
                    'software2': SoftwareKeyStoreBackend(),
                  }
                : null);
        var s2 = DateTime.now();
        logger.d(s2.difference(s).inMilliseconds);
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

Future<String> getNameExpansion() async {
  var dir = await getApplicationDocumentsDirectory();
  var path = dir.path;
  var nameExpansion = path.replaceAll('/', '_').replaceAll(r'\', '_');
  var split = nameExpansion.split('_');
  if (split.length > 3) {
    nameExpansion =
        '${split[split.length - 3]}${split[split.length - 2]}${split[split.length - 1]}';
  }
  logger.d(nameExpansion);
  return Platform.isIOS ? 'hidy' : nameExpansion;
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
          (!element.contains('HidyContext') && element != 'IsoMdlCredential'),
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
    backgroundColor: Colors.black.withValues(alpha: 0.6),
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
}

int? getCoseAlgorithmForDid(String did) {
  if (did.startsWith('did:key:z6Mk')) {
    return CoseAlgorithm.edDSA;
  } else if (did.startsWith('did:key:zQ3s')) {
    return CoseAlgorithm.es256;
  } else if (did.startsWith('did:key:zDn')) {
    return CoseAlgorithm.es256;
  } else if (did.startsWith('did:key:z82')) {
    return CoseAlgorithm.es384;
  } else if (did.startsWith('did:key:z2J9')) {
    return CoseAlgorithm.es512;
  } else {
    return null;
  }
}

class OsKeyStore extends KeyStoreBackend {
  final _instance = OsKeystoreBackend();

  @override
  FutureOr<Uint8List> calculateKeyAgreement(
      String keyId, Map<String, dynamic> otherPublicKey) {
    // TODO: implement calculateKeyAgreement
    throw UnimplementedError();
  }

  @override
  void deleteKey(String keyId) {
    _instance.deleteKey(keyId);
  }

  @override
  FutureOr export() {
    throw Exception('Export not supported');
  }

  @override
  FutureOr<String> generateKey(KeyType keyType, [additionalProperties]) {
    String curve;
    if (keyType == KeyType.p256) {
      curve = 'secp256r1';
    } else if (keyType == KeyType.p384) {
      curve = 'secp384r1';
    } else if (keyType == KeyType.p521) {
      curve = 'secp521r1';
    } else {
      throw Exception('Unsupported KeyType');
    }

    bool userAuth =
        additionalProperties?['userAuthenticationRequired'] ?? false;
    String attestationChallenge =
        additionalProperties?['attestationChallenge'] ?? '';
    bool invalidateByNewBiometric =
        additionalProperties?['invalidateByNewBiometric'] ?? true;
    int authType = additionalProperties?['authType'] ?? 2;

    AuthType authValue;
    switch (authType) {
      case 1:
        authValue = AuthType.deviceCredential;
        break;
      case 2:
        authValue = AuthType.biometricOnly;
        break;
      case 3:
        authValue = AuthType.deviceCredentialOrBiometric;
        break;
      default:
        authValue = AuthType.biometricOnly;
    }

    return _instance.generateKey(curve, userAuth,
        attestationChallenge: attestationChallenge,
        invalidateByNewBiometric: invalidateByNewBiometric,
        authType: authValue);
  }

  @override
  FutureOr<Map<String, dynamic>> getKeyInformation(String keyId) async {
    var p = (await _instance.getKeyInfo(keyId))
        .map((k, v) => MapEntry(k as String, v));
    p['kid'] = keyId;
    if (p.containsKey('x5c') && (p['x5c'] as List).isNotEmpty) {
      String? x, y, crv;
      (x, y, crv) = _parseCert((p['x5c'] as List).first);
      if (x != null) {
        p['x'] = x;
      }
      if (y != null) {
        p['y'] = y;
      }
      if (crv != null) {
        p['crv'] = crv;
      }
    }
    return p;
  }

  @override
  FutureOr<bool> hasKey(String keyId) {
    return _instance.hasKey(keyId);
  }

  @override
  FutureOr<void> import(data) {
    throw Exception('import not supported');
  }

  @override
  FutureOr<void> initializeStorage() {}

  @override
  FutureOr<Uint8List> signData(Uint8List data, String keyId) {
    return _instance.sign(
        keyId,
        data,
        BiometricPromptData(
            title: AppLocalizations.of(navigatorKey.currentContext!)!
                .biometricPromptTitle,
            subtitle: AppLocalizations.of(navigatorKey.currentContext!)!
                .biometricPromptSubtitle,
            negativeButton:
                AppLocalizations.of(navigatorKey.currentContext!)!.cancel));
  }

  @override
  FutureOr<bool> verify(
      Uint8List signature, Uint8List signedData, String keyId) {
    return _instance.verify(keyId, signedData, signature);
  }

  (String? x, String? y, String? crv) _parseCert(String cert) {
    var k = CoseKey.fromCertificate(cert);
    if (k.x != null && k.y != null && k.crv != null) {
      String? crv;
      if (k.crv == CoseCurve.p521) {
        crv = 'P-521';
      } else if (k.crv == CoseCurve.p384) {
        crv = 'P-384';
      } else if (k.crv == CoseCurve.p256) {
        crv = 'P-256';
      }
      return (
        removePaddingFromBase64(base64UrlEncode(k.x!)),
        removePaddingFromBase64(base64UrlEncode(k.y!)),
        crv
      );
    }
    return (null, null, null);
  }
}

Future<(CredentialSigner, LdpProofType)> getCredentialSigningStuff(
    WalletProvider wallet, String did) async {
  var keyId = wallet.getOsKeyStoreIdForDid(did) ?? did;
  var keyInfo = await wallet.wallet.getKeyInformation(keyId);
  String alg = 'EdDSA';
  LdpProofType type = LdpProofType.ed25519Signature2020;
  if (keyInfo['crv'] == 'P-256' || keyInfo['crv'] == 'secp256k1') {
    alg = 'ES256';
    type = LdpProofType.jsonWebSignature2020;
  } else if (keyInfo['crv'] == 'P-384') {
    alg = 'ES384';
    type = LdpProofType.jsonWebSignature2020;
  } else if (keyInfo['crv'] == 'P-521') {
    alg = 'ES512';
    type = LdpProofType.jsonWebSignature2020;
  }

  return (
    WalletCredentialSigner(
        wallet.wallet, keyId, alg, '$did#${did.split(':').last}'),
    type
  );
}

Future<void> getWalletAttestation() async {
  var nonceRes = await get(Uri.parse('http://localhost:8080/nonce'));
  if (nonceRes.statusCode == 200) {
    var nonce = jsonDecode(nonceRes.body)['nonce'];

    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    var keyId = await wallet.newCredentialDid(KeyType.p256, KeyStore.system);
    logger.d(keyId);
    var info = await wallet.wallet
        .getKeyInformation(wallet.getOsKeyStoreIdForDid(keyId)!);
    var jwt = sd_jwt.Jwt(
        additionalClaims: {'nonce': nonce},
        header: sd_jwt.JoseHeader(
            x509certificateChain: (info['x5c'] as List)
                .map((e) => base64Decode(e as String))
                .toList()));
    logger.d(jwt);
    var jws = await jwt.sign(
        header: sd_jwt.JwsJoseHeader(
            algorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime,
            x509certificateChain: (info['x5c'] as List)
                .map((e) => base64Decode(e as String))
                .toList()),
        signer: WalletCryptoProviderForSdJwt(
            wallet.wallet, wallet.getOsKeyStoreIdForDid(keyId)!),
        signingAlgorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime);
    logger.d(jws.header);
    var attRes = await get(
      Uri.parse('http://localhost:8080/attest/${jws.toCompactSerialization()}'),
    );
    logger.d(attRes.body);
  }
}

Future navigateClassic(Widget newView, [bool storeRoute = false]) {
  var route = Platform.isIOS
      ? CupertinoPageRoute(builder: (context) => newView)
      : MaterialPageRoute(builder: (context) => newView);
  if (storeRoute) {
    Provider.of<NavigationProvider>(navigatorKey.currentContext!, listen: false)
        .storedRoute = route;
  }
  return Navigator.of(navigatorKey.currentContext!).push(route);
}

class AboData {
  String name, url, pictureUrl, titleBgColorCode, titleFontColorCode;

  AboData(this.name, this.url, this.pictureUrl, this.titleBgColorCode,
      this.titleFontColorCode);

  factory AboData.fromJson(dynamic jsonData) {
    var data = credentialToMap(jsonData);

    return AboData(
        data['name'] ?? '',
        data['url'],
        data['mainbgimg'] ?? data['mainbgimage'],
        data['titleBgColor'] ?? '',
        data['titleBgColor'] ?? '');
  }

  String getComparableUrl() {
    var asUri = Uri.parse(url);
    return removeTrailingSlash('${asUri.scheme}://${asUri.host}${asUri.path}');
  }

  Color getTitleBgColor() {
    return titleBgColorCode.isEmpty
        ? Colors.white
        : HexColor.fromHex(titleBgColorCode);
  }

  Color getTitleFontColor() {
    return titleFontColorCode.isEmpty
        ? Colors.black
        : HexColor.fromHex(titleFontColorCode);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'mainbgimage': pictureUrl,
      'titleBgColor': titleBgColorCode,
      'titleFontColor': titleFontColorCode
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}

bool isRawJson(String json) {
  try {
    jsonDecode(json);
    return true;
  } catch (e) {
    return false;
  }
}

String coseKeyToDid(CoseKey coseKey) {
  var crvInt = coseKey.crv;

  Map<String, dynamic> jwk;
  if (crvInt == 6) {
    jwk = {
      'crv': 'Ed25519',
      'x': removePaddingFromBase64(base64UrlEncode(coseKey.x!))
    };
  } else if (crvInt == 1) {
    jwk = {
      'crv': 'P-256',
      'x': removePaddingFromBase64(base64UrlEncode(coseKey.x!)),
      'y': removePaddingFromBase64(base64UrlEncode(coseKey.y!))
    };
  } else if (crvInt == 2) {
    jwk = {
      'crv': 'P-384',
      'x': removePaddingFromBase64(base64UrlEncode(coseKey.x!)),
      'y': removePaddingFromBase64(base64UrlEncode(coseKey.y!))
    };
  } else if (crvInt == 3) {
    jwk = {
      'crv': 'P-521',
      'x': removePaddingFromBase64(base64UrlEncode(coseKey.x!)),
      'y': removePaddingFromBase64(base64UrlEncode(coseKey.y!))
    };
  } else {
    throw Exception('Unknown KeyType');
  }

  return 'did:key:${jwkToMultiBase(jwk)}';
}

SecureRandom getSecureRandom() {
  final secureRandom = FortunaRandom();

  var random = Random.secure();
  var seed = List.generate(32, (index) => random.nextInt(256));

  secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));

  return secureRandom;
}
