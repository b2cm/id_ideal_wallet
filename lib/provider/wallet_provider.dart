import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/constants/root_certificates.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:pkcs7/pkcs7.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  bool _authRunning = false;
  bool onboard;

  bool openError = false;

  String? lndwId;
  String tosUrl = 'https://hidy.eu/terms.html';
  String aboutUrl = 'https://hidy.eu';

  SortingType sortingType = SortingType.dateDown;

  Map<String, List<ExchangeHistoryEntry>> lastPayments = {};
  Map<String, double> balance = {};
  Timer? paymentTimer;

  List<VerifiableCredential> credentials = [];
  List<VerifiableCredential> paymentCredentials = [];
  List<Credential> isoMdocCredentials = [];

  //[[url, pic-url], [url, pic-url], ...]
  List<Map<String, String>> aboList = [];
  Map<String, Map<String, String>> credentialStyling = {};

  DateTime? lastCheckRevocation;
  Map<String, int> revocationState = {};

  static const platform = MethodChannel('app.channel.shared.data');
  static const stream = EventChannel('app.channel.shared.data/events');

  List<int> dataShared = [];

  WalletProvider(String walletPath, [this.onboard = true])
      : _wallet = WalletStore(walletPath, Platform.isIOS ? 'hidy' : null);

  Future<List<int>?> startUri() async {
    try {
      return platform.invokeMethod('getSharedText');
    } on PlatformException catch (e) {
      logger.d('cant fetch pkpass: $e');
    }
    return null;
  }

  (String, Map) getPassType(Map<String, dynamic> pass) {
    if (pass.containsKey('boardingPass')) {
      return ('BoardingPass', pass.remove('boardingPass'));
    } else if (pass.containsKey('coupon')) {
      return ('Coupon', pass.remove('coupon'));
    } else if (pass.containsKey('eventTicket')) {
      return ('EventTicket', pass.remove('eventTicket'));
    } else if (pass.containsKey('storeCard')) {
      return ('StoreCard', pass.remove('storeCard'));
    } else {
      return ('Generic', pass.remove('generic'));
    }
  }

  toKeyAndValue(Map goal, List data) {
    for (var d in data) {
      goal[d['label'] ?? d['key']] = d['value'];
    }
  }

  String rgbColorToHex(String rgb) {
    var color = rgb.replaceAll('rgb(', '').replaceAll(')', '');
    var values = color.split(',');
    var asInt = values.map((e) => int.parse(e.trim()).toRadixString(16));
    var hexColor = asInt.join();
    return '#$hexColor';
  }

  void getSharedText(List<int>? sharedData) async {
    if (sharedData != null) {
      try {
        dataShared = sharedData;
        logger.d(dataShared.length);
        var archive = ZipDecoder().decodeBytes(dataShared);
        var passFile = archive.findFile('pass.json');
        var sigFile = archive.findFile('signature');
        var manifestFile = archive.findFile('manifest.json');
        if (sigFile != null && manifestFile != null) {
          var parsed = Pkcs7.fromDer(sigFile.content);
          var info = parsed.verify([appleRootCert, appleComputerRootCert]);
          var hash = sha256.convert(manifestFile.content).bytes;
          var manifestAsJson = jsonDecode(utf8.decode(manifestFile.content));
          var givenPassHash = manifestAsJson['pass.json'];
          var valid =
              info.listEquality(info.messageDigest!, Uint8List.fromList(hash));
          if (givenPassHash == null || passFile == null) {
            valid = false;
          } else {
            var passHash = sha1.convert(passFile.content).toString();
            logger.d('$passHash ==? $givenPassHash');
            valid = givenPassHash == passHash;
          }
          if (!valid) {
            logger.d('Invalid pkpass signature');
            showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
                .importFailed);
            return;
          }
        }
        if (passFile != null) {
          var passAsJson = jsonDecode(utf8.decode(passFile.content));
          String type;
          Map mainPassData;
          (type, mainPassData) = getPassType(passAsJson);
          if (passAsJson['backgroundColor'] != null) {
            String color = passAsJson['backgroundColor'];
            if (!color.startsWith('#')) {
              if (color.startsWith('rgb')) {
                passAsJson['backgroundColor'] = rgbColorToHex(color);
              }
            }
          }
          if (passAsJson['foregroundColor'] != null) {
            String color = passAsJson['foregroundColor'];
            if (!color.startsWith('#')) {
              if (color.startsWith('rgb')) {
                passAsJson['foregroundColor'] = rgbColorToHex(color);
              }
            }
          }
          Map<String, dynamic> simplyfiedData = {};
          if (mainPassData.containsKey('headerFields')) {
            var fields = mainPassData['headerFields'] as List;
            toKeyAndValue(simplyfiedData, fields);
          }
          if (mainPassData.containsKey('auxiliaryFields')) {
            var fields = mainPassData['auxiliaryFields'] as List;
            toKeyAndValue(simplyfiedData, fields);
          }
          if (mainPassData.containsKey('backFields')) {
            var fields = mainPassData['backFields'] as List;
            toKeyAndValue(simplyfiedData, fields);
          }
          if (mainPassData.containsKey('primaryFields')) {
            var fields = mainPassData['primaryFields'] as List;
            toKeyAndValue(simplyfiedData, fields);
          }
          if (mainPassData.containsKey('secondaryFields')) {
            var fields = mainPassData['secondaryFields'] as List;
            toKeyAndValue(simplyfiedData, fields);
          }
          if (mainPassData.containsKey('transitType')) {
            simplyfiedData['transitType'] = mainPassData['transitType'];
          }

          var did = await newCredentialDid();

          logger.d(passAsJson);

          var vc = VerifiableCredential(
              context: [credentialsV1Iri, 'schema.org'],
              type: [type, 'PkPass'],
              issuer: did,
              credentialSubject: {'id': did, ...passAsJson, ...simplyfiedData},
              issuanceDate: DateTime.now());

          var signed = await signCredential(_wallet, vc.toJson());
          var storageCred = getCredential(did);
          storeCredential(signed, storageCred!.hdPath);
          storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
          showSuccessMessage(AppLocalizations.of(navigatorKey.currentContext!)!
              .importSuccess(type));
        } else {
          logger.d('no valid pkpassFile');
          showErrorMessage(
              AppLocalizations.of(navigatorKey.currentContext!)!.importFailed);
        }
      } catch (e) {
        logger.d(e);
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.importFailed);
      }
    }
  }

  void onBoarded() {
    onboard = true;
  }

  void openWallet() async {
    if (!_authRunning) {
      Provider.of<MdocProvider>(navigatorKey.currentContext!, listen: false)
          .startListening();
      _authRunning = true;
      var isOpen = await my_util.openWallet(_wallet);
      if (!isOpen) {
        openError = true;
        return;
      }

      if (!_wallet.isInitialized()) {
        await _wallet.initialize();
        await _wallet.initializeIssuer(KeyType.ed25519);
      }

      _buildCredentialList();

      var e = _wallet.getConfigEntry('aboList');
      if (e != null) {
        List dec = jsonDecode(e);
        aboList = dec.map((e) => (e as Map).cast<String, String>()).toList();
      }

      var t = wallet.getConfigEntry('tosUrl');
      if (t != null) tosUrl = t;

      var a = wallet.getConfigEntry('aboutUrl');
      if (a != null) {
        aboutUrl = a;
      }

      var lastUpdateCheck = _wallet.getConfigEntry('lastUpdateCheck');
      if (lastUpdateCheck != null) {
        logger.d(
            'lastUpdate: ${DateTime.now().difference(DateTime.parse(lastUpdateCheck))}');
      }
      if (lastUpdateCheck == null ||
          DateTime.now().difference(DateTime.parse(lastUpdateCheck)) >=
              Duration(days: testBuild ? 0 : 1, seconds: testBuild ? 1 : 0)) {
        logger.d('with request');
        generateCredentialStyling(true);
        updateTosUrl();
        _wallet.storeConfigEntry(
            'lastUpdateCheck', DateTime.now().toIso8601String());
      } else {
        logger.d('without request');
        generateCredentialStyling();
      }

      lndwId = _wallet.getConfigEntry('lndwId');
      if (lndwId == null) {
        lndwId = const Uuid().v4();
        _wallet.storeConfigEntry('lndwId', lndwId!);
      }

      var lastCheck = _wallet.getConfigEntry('lastValidityCheckTime');
      var revState = _wallet.getConfigEntry('revocationState');
      if (revState != null) {
        Map<String, dynamic> tmp = jsonDecode(revState);
        revocationState = tmp.cast<String, int>();
      }
      if (lastCheck == null || revocationState.isEmpty) {
        checkValidity();
      } else {
        lastCheckRevocation = DateTime.parse(lastCheck);
        if (DateTime.now().difference(lastCheckRevocation!) >=
            const Duration(days: 1)) {
          checkValidity();
        }
      }

      _authRunning = false;

      startUri().then(getSharedText);
      //Checking broadcast stream, if deep link was clicked in opened application
      stream.receiveBroadcastStream().listen((d) => getSharedText(d));

      notifyListeners();
    }
  }

  Future<void> generateCredentialStyling([bool request = false]) async {
    var s = _wallet.getConfigEntry('credentialStyling');
    if (s == null || request) {
      var res = await get(Uri.parse(stylingEndpoint));
      if (res.statusCode == 200) {
        credentialStyling = (jsonDecode(res.body) as Map<String, dynamic>).map(
            (key, value) =>
                MapEntry(key, (value as Map).cast<String, String>()));
      } else {
        credentialStyling = {};
      }

      _wallet.storeConfigEntry(
          'credentialStyling', jsonEncode(credentialStyling));
    } else {
      credentialStyling = (jsonDecode(s) as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as Map).cast<String, String>()));
    }

    logger.d(credentialStyling);
  }

  Future<void> updateTosUrl() async {
    var data = await get(Uri.parse(termsVersionEndpoint));
    if (data.statusCode == 200) {
      var asJson = jsonDecode(data.body);
      if (asJson['url'] != null) {
        tosUrl = asJson['url'];
        logger.d(tosUrl);
      }
      if (asJson['about']['url'] != null) {
        aboutUrl = (asJson['about'] as Map)['url'];
        logger.d(aboutUrl);
      }

      wallet.storeConfigEntry('tosUrl', tosUrl);
      wallet.storeConfigEntry('aboutUrl', aboutUrl);
    }
  }

  void deleteAbo(int index) async {
    aboList.removeAt(index);
    await wallet.storeConfigEntry('aboList', jsonEncode(aboList));
    notifyListeners();
  }

  Map<String, dynamic> getAboData(String id) {
    var e = _wallet.getConfigEntry(id);
    if (e != null) {
      return jsonDecode(e) as Map<String, dynamic>;
    } else {
      return {};
    }
  }

  void addAbo(String url, String pictureUrl, String title,
      [bool cheat = false, bool notify = true]) {
    aboList.add({'url': url, 'mainbgimage': pictureUrl, 'name': title});
    wallet.storeConfigEntry('aboList', jsonEncode(aboList));

    if (notify) notifyListeners();
  }

  List<String> getAuthorizedApps() {
    var e = _wallet.getConfigEntry('authorizedApps');
    return e == null ? [] : jsonDecode(e).cast<String>();
  }

  void deleteAuthorizedApp(String uri) async {
    var e = _wallet.getConfigEntry('authorizedApps');
    List<String> old = e == null ? <String>[] : jsonDecode(e).cast<String>();
    old.remove(uri);
    await _wallet.storeConfigEntry('authorizedApps', jsonEncode(old));
    await _wallet.deleteConfigEntry('hash_$uri');
    notifyListeners();
  }

  void addAuthorizedApp(String uri, String hash) async {
    var e = _wallet.getConfigEntry('authorizedApps');
    List<String> old = e == null ? <String>[] : jsonDecode(e).cast<String>();
    old.add(uri);
    await _wallet.storeConfigEntry('authorizedApps', jsonEncode(old));

    var h = _wallet.getConfigEntry('hash_$uri');
    List<String> hashes = h == null ? <String>[] : jsonDecode(h).cast<String>();
    hashes.add(hash);
    await _wallet.storeConfigEntry('hash_$uri', jsonEncode(hashes));

    notifyListeners();
  }

  List<String> getHashesForAuthorizedApp(String uri) {
    var e = _wallet.getConfigEntry('hash_$uri');
    return e == null ? [] : jsonDecode(e).cast<String>();
  }

  Future<void> checkValiditySingle(VerifiableCredential vc,
      [bool notify = false]) async {
    var id = getHolderDidFromCredential(vc.toJson());
    if (id == '') {
      var type = my_util.getTypeToShow(vc.type);
      id = '${vc.issuanceDate.toIso8601String()}$type';
    }
    logger.d(vc);

    // check states that won't change to speed up
    var lastState = revocationState[id];
    if (lastState == RevocationState.revoked.index ||
        lastState == RevocationState.expired.index) {
      return;
    }

    // check expiration date
    if (vc.expirationDate != null &&
        vc.expirationDate!.isBefore(DateTime.now())) {
      revocationState[id] = RevocationState.expired.index;
      return;
    }

    // check status
    if (vc.status != null) {
      logger.d(vc.status);
      try {
        var revoked = await checkForRevocation(vc);
        if (!revoked) {
          revocationState[id] = RevocationState.valid.index;
        }
      } on RevokedException catch (e) {
        if (e.code == 'revErr') {
          revocationState[id] = RevocationState.unknown.index;
        } else if (e.code == 'rev') {
          revocationState[id] = RevocationState.revoked.index;
        } else if (e.code == 'sus') {
          revocationState[id] = RevocationState.suspended.index;
        } else {
          revocationState[id] = RevocationState.unknown.index;
        }
      } on Exception catch (_) {
        revocationState[id] = RevocationState.unknown.index;
      }
      return;
    }

    revocationState[id] = RevocationState.valid.index;

    await _wallet.storeConfigEntry(
        'revocationState', jsonEncode(revocationState));

    if (notify) notifyListeners();
  }

  void checkValidity() async {
    lastCheckRevocation = DateTime.now();
    await _wallet.storeConfigEntry(
        'lastValidityCheckTime', lastCheckRevocation!.toIso8601String());

    for (var vc in credentials) {
      await checkValiditySingle(vc);
    }

    notifyListeners();
  }

  String? getLnInKey(String paymentId) {
    return _wallet.getConfigEntry('lnInKey$paymentId');
  }

  String? getLnAdminKey(String paymentId) {
    return _wallet.getConfigEntry('lnAdminKey$paymentId');
  }

  void getLnBalance(String paymentId) async {
    var a = await getBalance(getLnInKey(paymentId)!);
    balance[paymentId] = a.toSat();
    notifyListeners();
  }

  void storeLnAccount(String paymentId, Map<String, dynamic> accountData,
      {bool isMainnet = false}) async {
    var wallets = accountData['wallets'] as List;
    var w = wallets.first;
    var lnAdminKey = w['adminkey'];
    var lnInKey = w['inkey'];

    if (lnAdminKey == null || lnInKey == null) {
      throw Exception('AdminKey or inKey null - this should not happen');
      // Todo message to user
    }

    await _wallet.storeConfigEntry('lnAdminKey$paymentId', lnAdminKey!);
    await _wallet.storeConfigEntry('lnInKey$paymentId', lnInKey!);
    await _wallet.storeConfigEntry(
        'lnPaymentType$paymentId', isMainnet ? 'mainnet' : 'testnet');
    await _wallet.storeConfigEntry(
        'lnDetails$paymentId', jsonEncode(accountData));

    notifyListeners();
  }

  void storePayment(String paymentId, String action, String otherParty,
      {List<String>? belongingCredentials, DateTime? timestamp}) async {
    _wallet.storeExchangeHistoryEntry('paymentHistory$paymentId',
        timestamp ?? DateTime.now(), action, otherParty, belongingCredentials);
    _updateLastThreePayments(paymentId);
    getLnBalance(paymentId);
    notifyListeners();
  }

  void newPayment(
      String paymentId, String paymentHash, String memo, SatoshiAmount amount) {
    paymentTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      var paid = await isInvoicePaid(getLnInKey(paymentId)!, paymentHash);
      logger.d(paymentHash);
      if (paid) {
        timer.cancel();
        storePayment(paymentId, '+${amount.toSat()}',
            memo == '' ? 'Lightning Invoice' : memo);
        paymentTimer = null;
        showModalBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline: AppLocalizations.of(navigatorKey.currentContext!)!
                      .paymentReceived,
                  success: true,
                  amount: CurrencyDisplay(
                      amount: "+${amount.toSat()}",
                      symbol: 'sat',
                      mainFontSize: 35,
                      centered: true),
                ),
              );
            });
      }
    });
  }

  void _updateLastThreePayments(String paymentId) {
    var payments = getAllPayments(paymentId);
    if (payments.length > 1) {
      payments.sort((e1, e2) {
        if (e1.timestamp.isBefore(e2.timestamp)) {
          return 1;
        } else if (e1.timestamp.isAfter(e2.timestamp)) {
          return -1;
        } else {
          return 0;
        }
      });
    }
    if (payments.length <= 3) {
      lastPayments[paymentId] = payments;
    } else {
      lastPayments[paymentId] = [payments.first, payments[1], payments[2]];
    }
  }

  void reIssuePaymentContext(
      VerifiableCredential old, Map<String, dynamic> newContent) async {
    var did = old.id!;
    var contextId =
        old.credentialSubject['paymentType'] == 'LightningMainnetPayment'
            ? '2'
            : '3';
    var contextCred = VerifiableCredential(
        context: [credentialsV1Iri, schemaOrgIri],
        type: ['VerifiableCredential', 'ContextCredential', 'PaymentContext'],
        issuer: did,
        id: did,
        credentialSubject: {
          'id': did,
          'contextId': contextId,
          'paymentType': old.credentialSubject['paymentType'],
          ...newContent
        },
        issuanceDate: DateTime.now());

    var signed = await signCredential(_wallet, contextCred.toJson());
    var storageCred = wallet.getCredential(did);
    storeCredential(signed, storageCred!.hdPath);
    storeExchangeHistoryEntry(did, DateTime.now(), 'update', did);

    notifyListeners();
  }

  void _buildCredentialList() {
    credentials = [];
    paymentCredentials = [];
    isoMdocCredentials = [];

    var all = allCredentials();
    for (var cred in all.values) {
      if (cred.w3cCredential == '' || cred.w3cCredential == 'vc') {
        continue;
      }
      if (cred.plaintextCredential == '' ||
          cred.plaintextCredential.startsWith('isoData:')) {
        if (cred.plaintextCredential.startsWith('isoData:')) {
          isoMdocCredentials.add(cred);
        }
        var vc = VerifiableCredential.fromJson(cred.w3cCredential);
        if (vc.type.contains('PaymentContext')) {
          paymentCredentials.add(vc);
          _updateLastThreePayments(vc.id!);

          getLnBalance(vc.id!);
        } else {
          if (!vc.type.contains('PaymentReceipt')) {
            credentials.add(vc);
          }
        }
      } else {
        // TODO: merge w3c and Plaintext credential
      }
    }

    logger.d(paymentCredentials.map((e) => e.id).join(';'));

    if (sortingType == SortingType.dateDown ||
        sortingType == SortingType.dateUp) {
      credentials.sort(
        (a, b) {
          if (a.issuanceDate.isAfter(b.issuanceDate)) {
            return sortingType == SortingType.dateDown ? -1 : 1;
          } else if (a.issuanceDate.isBefore(b.issuanceDate)) {
            return sortingType == SortingType.dateDown ? 1 : -1;
          } else {
            return 0;
          }
        },
      );
    } else {
      credentials.sort(
        (a, b) {
          var typeA = my_util.getTypeToShow(a.type);
          var typeB = my_util.getTypeToShow(b.type);
          return typeA.compareTo(typeB);
        },
      );
      if (sortingType == SortingType.typeDown) {
        credentials = credentials.reversed.toList();
      }
    }
  }

  void changeSortingType(SortingType newType) {
    sortingType = newType;
    _buildCredentialList();
    notifyListeners();
  }

  List<ExchangeHistoryEntry> getAllPayments(String paymentId) {
    return _wallet.getExchangeHistoryEntriesForCredential(
            'paymentHistory$paymentId') ??
        [];
  }

  void storeConversation(DidcommPlaintextMessage message, String myDid) {
    _wallet.storeConversationEntry(message, myDid);
  }

  void storeConfig(String key, String value) async {
    await _wallet.storeConfigEntry(key, value);
  }

  String? getConfig(String key) {
    return _wallet.getConfigEntry(key);
  }

  bool isOpen() {
    return _wallet.isWalletOpen();
  }

  DidcommConversation? getConversation(String id) {
    return _wallet.getConversationEntry(id);
  }

  Future<String> newConnectionDid([KeyType keytype = KeyType.x25519]) async {
    return _wallet.getNextConnectionDID(keytype, true);
  }

  Connection? getConnection(String did) {
    return _wallet.getConnection(did);
  }

  Future<String> newCredentialDid([KeyType keytype = KeyType.ed25519]) async {
    return _wallet.getNextCredentialDID(keytype, true);
  }

  Credential? getCredential(String did) {
    return _wallet.getCredential(did);
  }

  void storeCredential(String vc, String hdPath,
      {String? newDid,
      String? isoMdlData,
      KeyType keyType = KeyType.ed25519}) async {
    await _wallet.storeCredential(vc, isoMdlData ?? '', hdPath,
        keyType: keyType, credDid: newDid);
    _buildCredentialList();
    var vcParsed = VerifiableCredential.fromJson(vc);
    var type = vcParsed.type
        .firstWhere((element) => element != 'VerifiableCredential');
    logger.d(type);

    if (type == 'PieceOfArt') {
      List<String> allAbos = aboList.map((e) {
        return e['url']!;
      }).toList();
      if (!allAbos.contains('https://test.hidy.app/kigallery')) {
        addAbo(
            'https://test.hidy.app/kigallery',
            'https://hidy.app/styles/kigalerie_contextbg.jpg',
            'KI-Galerie',
            true,
            false);
      }
    }
    await checkValiditySingle(vcParsed);
    notifyListeners();
    var nav = Provider.of<NavigationProvider>(navigatorKey.currentContext!,
        listen: false);
    if (nav.redirectWebViewUrl != null) {
      nav.changePage([NavigationPage.credential], track: false);
      Timer(const Duration(milliseconds: 10), () {
        nav.changePage([NavigationPage.webView],
            webViewUrl: nav.redirectWebViewUrl);
        nav.redirectWebViewUrl = null;
      });
    }
  }

  Future<Map<String, dynamic>?> privateKeyForConnectionDidAsJwk(String did) {
    return _wallet.getPrivateKeyForConnectionDidAsJwk(did);
  }

  Future<String?> getPrivateKeyForCredentialDid(String did) {
    return _wallet.getPrivateKeyForCredentialDid(did);
  }

  Map<dynamic, Connection> allConnections() {
    return _wallet.getAllConnections();
  }

  Map<dynamic, Credential> allCredentials() {
    return _wallet.getAllCredentials();
  }

  void deleteCredential(String credDid, [bool notify = false]) async {
    var cred = getCredential(credDid);
    logger.d(credDid);
    logger.d(cred);
    if (cred != null) {
      await _wallet.deleteCredential(credDid);
      await _wallet.deleteExchangeHistory(credDid);
      // await _wallet.deleteConfigEntry(credDid);
    }
    _buildCredentialList();
    if (notify) {
      notifyListeners();
    }
  }

  void storeExchangeHistoryEntry(String credentialDid, DateTime timestamp,
      dynamic action, dynamic otherParty) async {
    await _wallet.storeExchangeHistoryEntry(
        credentialDid, timestamp, action, otherParty);
    notifyListeners();
  }

  List<ExchangeHistoryEntry> historyEntriesForCredential(String credDid) {
    return _wallet.getExchangeHistoryEntriesForCredential(credDid) ?? [];
  }

  Future<void> addMemberCard(Map<String, String> subject) async {
    var did = await newCredentialDid();
    var storage = getCredential(did);
    var vc = VerifiableCredential(
        context: [credentialsV1Iri, schemaOrgIri],
        issuer: did,
        issuanceDate: DateTime.now(),
        type: ['VerifiableCredential', 'MemberCard'],
        credentialSubject: {'id': did, ...subject});

    var signed = await signCredential(_wallet, vc.toJson());
    storeCredential(signed, storage!.hdPath);
    wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
  }

  WalletStore get wallet => _wallet;
}

enum SortingType { dateUp, dateDown, typeUp, typeDown }

enum RevocationState { valid, expired, suspended, revoked, unknown }
