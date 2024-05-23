import 'dart:async';
import 'dart:convert';

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
import 'package:id_ideal_wallet/constants/root_certificates.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart'
    as local;
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';
import 'package:pkcs7/pkcs7.dart';
import 'package:uuid/uuid.dart';

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  bool _authRunning = false;
  bool onboard;

  // bool _hasMemberCardContext = false;
  Set<int> favoriteIndex = {};
  Set<String> hasUpdate = {};
  DateTime? lastCheckForUpdates;

  bool openError = false;

  String qrData = '';
  String? lndwId;

  late Timer t;
  SortingType sortingType = SortingType.dateDown;

  Map<String, List<ExchangeHistoryEntry>> lastPayments = {};
  Map<String, double> balance = {};
  Timer? paymentTimer;

  List<VerifiableCredential> credentials = [];
  List<VerifiableCredential> contextCredentials = [];
  List<VerifiableCredential> paymentCredentials = [];

  //[[url, pic-url], [url, pic-url], ...]
  List<Map<String, String>> aboList = [];
  Map<String, Map<String, String>> credentialStyling = {};

  List<String> relayedDids = [];
  DateTime? lastCheckRevocation;
  Map<String, int> revocationState = {};

  static const platform = MethodChannel('app.channel.shared.data');
  static const stream = EventChannel('app.channel.shared.data/events');

  List<int> dataShared = [];

  WalletProvider(String walletPath, [this.onboard = true])
      : _wallet = WalletStore(walletPath) {
    // t = Timer.periodic(const Duration(seconds: 10), checkRelay);
  }

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
            my_util.showScaffoldMessenger(
                navigatorKey.currentContext!,
                AppLocalizations.of(navigatorKey.currentContext!)!
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

          var vc = VerifiableCredential(
              context: ['schema.org'],
              type: [type, 'PkPass'],
              issuer: did,
              credentialSubject: {'id': did, ...passAsJson, ...simplyfiedData},
              issuanceDate: DateTime.now());

          var signed = await signCredential(_wallet, vc.toJson());
          var storageCred = getCredential(did);
          storeCredential(signed, storageCred!.hdPath);
          storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
          my_util.showScaffoldMessenger(
              navigatorKey.currentContext!,
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .importSuccess(type));
        } else {
          logger.d('no valid pkpassFile');
          my_util.showScaffoldMessenger(navigatorKey.currentContext!,
              AppLocalizations.of(navigatorKey.currentContext!)!.importFailed);
        }
      } catch (e) {
        logger.d(e);
        my_util.showScaffoldMessenger(navigatorKey.currentContext!,
            AppLocalizations.of(navigatorKey.currentContext!)!.importFailed);
      }
    }
  }

  void onBoarded() {
    onboard = true;
  }

  void openWallet() async {
    if (!_authRunning) {
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

      await updateStorage();

      _buildCredentialList();

      generateAboGroups();

      var lastUpdateCheck = _wallet.getConfigEntry('lastUpdateCheck');
      if (lastUpdateCheck == null ||
          DateTime.now().difference(DateTime.parse(lastUpdateCheck)) >=
              const Duration(days: 1)) {
        logger.d('with request');
        generateCredentialStyling(true);
        _wallet.storeConfigEntry(
            'lastUpdateCheck', DateTime.now().toIso8601String());
      } else {
        logger.d('without request');
        generateCredentialStyling();
      }

      // if (contextCredentials.isEmpty) {
      //   //await issueLNDWContextMittweida(this);
      //   await issueLNDWContextDresden(this);
      // }

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

      var favorites = _wallet.getConfigEntry('favorites');
      if (favorites == null) {
        _wallet.storeConfigEntry('favorites', jsonEncode([]));
      }

      // var memberContext = _wallet.getConfigEntry('hasMemberCardContext');
      // if (memberContext != null) {
      //   _hasMemberCardContext = true;
      // }

      var updateable = _wallet.getConfigEntry('updateContext');

      lastUpdateCheck = null;
      if (updateable == null || lastUpdateCheck == null) {
        checkForContextUpdates();
      } else if (DateTime.now().difference(DateTime.parse(lastUpdateCheck)) >=
          const Duration(days: 1)) {
        checkForContextUpdates();
      } else {
        lastCheckForUpdates = DateTime.parse(lastUpdateCheck);
        hasUpdate = (jsonDecode(updateable) as List).toSet().cast<String>();
      }

      _authRunning = false;

      var relayedDidsEntry = wallet.getConfigEntry('relayedDids');
      if (relayedDidsEntry != null && relayedDidsEntry.isNotEmpty) {
        relayedDids = jsonDecode(relayedDidsEntry).cast<String>();
      }

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

  void generateAboGroups() {
    var e = _wallet.getConfigEntry('aboList');
    if (e == null) {
      // generate from contextCredentials
      for (var vc in contextCredentials) {
        List services = vc.credentialSubject['buttons'] ??
            vc.credentialSubject['services'] ??
            [];

        if (services.isNotEmpty) {
          for (Map entry in services) {
            var bg = vc.credentialSubject['mainbgimg'] ?? '';
            if (entry['url'] == 'https://test.hidy.app/kigallery') {
              bg =
                  'https://test.hidy.app/styles/hidycontextplaceholder_contextbg.png';
            }
            aboList.add({
              'url': entry['url'],
              'mainbgimage': bg,
              'name': entry['name']
            });
          }
        }
      }
      wallet.storeConfigEntry('aboList', jsonEncode(aboList));
    } else {
      List dec = jsonDecode(e);
      aboList = dec.map((e) => (e as Map).cast<String, String>()).toList();
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

  void addAbo(String url, String pictureUrl, String title) {
    var asUri = Uri.parse(url);
    var toSave =
        '${asUri.scheme.isNotEmpty ? asUri.scheme : 'https'}://${asUri.host}${asUri.path}';
    aboList.add({'url': url, 'mainbgimage': pictureUrl, 'name': title});
    wallet.storeConfigEntry('aboList', jsonEncode(aboList));

    notifyListeners();
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

  Future<void> addToFavorites(String id) async {
    var f = jsonDecode(_wallet.getConfigEntry('favorites')!) as List;
    f.add(id);
    await _wallet.storeConfigEntry('favorites', jsonEncode(f));
    notifyListeners();
  }

  Future<void> removeFromFavorites(String id) async {
    var f = jsonDecode(_wallet.getConfigEntry('favorites')!) as List;
    f.remove(id);
    await _wallet.storeConfigEntry('favorites', jsonEncode(f));
    //notifyListeners();
  }

  bool isFavorite(String id) {
    var f = jsonDecode(_wallet.getConfigEntry('favorites')!) as List;
    return f.contains(id);
  }

  List getFavorites() {
    return jsonDecode(_wallet.getConfigEntry('favorites')!) as List;
  }

  String? getLnInKey(String paymentId) {
    return _wallet.getConfigEntry('lnInKey$paymentId');
  }

  String? getLnAdminKey(String paymentId) {
    return _wallet.getConfigEntry('lnAdminKey$paymentId');
  }

  String? getLnPaymentType(String paymentId) {
    return _wallet.getConfigEntry('lnPaymentType$paymentId');
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

  Future<void> updateStorage() async {
    var lnAccount = _wallet.getConfigEntry('lnDetails');
    logger.d(lnAccount);
    if (lnAccount != null) {
      // There is an account that needs to be converted into a context credential
      var asJson = jsonDecode(lnAccount);
      var did = await newCredentialDid();
      var contextCred = VerifiableCredential(
          context: [credentialsV1Iri, schemaOrgIri],
          type: ['VerifiableCredential', 'ContextCredential', 'PaymentContext'],
          issuer: did,
          id: did,
          credentialSubject: {
            'id': did,
            'name': 'Lightning Testnet Account',
            'paymentType': 'LightningTestnetPayment'
          },
          issuanceDate: DateTime.now());

      var signed = await signCredential(_wallet, contextCred.toJson());

      storeLnAccount(did, asJson);
      var storageCred = getCredential(did);
      storeCredential(signed, storageCred!.hdPath);
      storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);

      var paymentHistory = getAllPayments('');
      if (paymentHistory.isNotEmpty) {
        for (var e in paymentHistory) {
          storePayment(did, e.action, e.otherParty,
              belongingCredentials: e.shownAttributes, timestamp: e.timestamp);
        }
      }

      _wallet.deleteConfigEntry('lnAdminKey');
      _wallet.deleteConfigEntry('lnInKey');
      _wallet.deleteConfigEntry('lnDetails');
      _wallet.deleteExchangeHistory('paymentHistory');
    }
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

  void getLnBalance(String paymentId) async {
    var payType = getLnPaymentType(paymentId);
    var a = await getBalance(getLnInKey(paymentId)!,
        isMainnet: payType == 'mainnet');
    balance[paymentId] = a.toSat();
    notifyListeners();
  }

  void createFakePayment(String paymentId) async {
    await _wallet.storeConfigEntry('balance$paymentId', '10000');
    balance[paymentId] = 10000;
    notifyListeners();
  }

  void fakePay(String paymentId, double amount) async {
    var value = double.tryParse(_wallet.getConfigEntry('balance$paymentId')!);
    if (value != null) {
      value -= amount;
      await _wallet.storeConfigEntry(
          'balance$paymentId', value.toStringAsFixed(2));
      balance[paymentId] = value;
      notifyListeners();
    }
  }

  void getFakeBalance(String paymentId) {
    balance[paymentId] =
        double.parse(_wallet.getConfigEntry('balance$paymentId') ?? '0.0');
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
      var payType = getLnPaymentType(paymentId);
      var paid = await isInvoicePaid(getLnInKey(paymentId)!, paymentHash,
          isMainnet: payType == 'mainnet');
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

  List<VerifiableCredential> getSuitablePaymentCredentials(String invoice) {
    var pay = <VerifiableCredential>[];

    String paymentType = '';
    if (invoice.startsWith('lnbc') || invoice.startsWith('LNBC')) {
      paymentType = 'LightningMainnetPayment';
    } else if (invoice.startsWith('lntb')) {
      paymentType = 'LightningTestnetPayment';
    } else {
      paymentType = 'SimulatedPayment';
    }

    for (var p in paymentCredentials) {
      if (p.credentialSubject['paymentType'] == paymentType) {
        pay.add(p);
      }
    }

    return pay;
  }

  List<VerifiableCredential> getSuitablePaymentCredentialsForNetwork(
      String network) {
    var pay = <VerifiableCredential>[];

    String paymentType = '';
    if (network.toLowerCase() == 'mainnet') {
      paymentType = 'LightningMainnetPayment';
    } else if (network.toLowerCase() == 'testnet') {
      paymentType = 'LightningTestnetPayment';
    } else {
      paymentType = 'SimulatedPayment';
    }

    for (var p in paymentCredentials) {
      if (p.credentialSubject['paymentType'] == paymentType) {
        pay.add(p);
      }
    }

    return pay;
  }

  void removeIdFromUpdateList(String id) async {
    hasUpdate.remove(id);
    _wallet.storeConfigEntry('updateContext', jsonEncode(hasUpdate.toList()));
    notifyListeners();
  }

  Future<void> checkForContextUpdates() async {
    for (var context in contextCredentials) {
      var id = context.credentialSubject['contextId'];
      logger.d(id);
      if (id != null) {
        var onlineInfo = await get(Uri.parse('$contextEndpoint&contextid=$id'));
        if (onlineInfo.statusCode == 200) {
          var parsed = jsonDecode(onlineInfo.body);
          logger.d(
              '${parsed['version']} != ${context.credentialSubject['version']}');
          if (parsed['version'] != context.credentialSubject['version']) {
            if (context.type.contains('PaymentContext')) {
              hasUpdate.add('${id}_${context.id}');
            } else {
              hasUpdate.add(id);
            }
          }
        }
      } else {
        var payType = context.credentialSubject['paymentType'];
        if (payType != null) {
          hasUpdate.add(payType == 'LightningMainnetPayment'
              ? '2_${context.id}'
              : '3_${context.id}');
        } else {
          hasUpdate.add(id);
        }
      }
    }
    _wallet.storeConfigEntry('updateContext', jsonEncode(hasUpdate.toList()));
    lastCheckForUpdates = DateTime.now();
    _wallet.storeConfigEntry(
        'lastUpdateCheck', lastCheckForUpdates!.toIso8601String());

    notifyListeners();
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

    hasUpdate.remove('${contextId}_$did');

    notifyListeners();
  }

  void _buildCredentialList() {
    credentials = [];
    contextCredentials = [];
    paymentCredentials = [];

    var all = allCredentials();
    for (var cred in all.values) {
      if (cred.w3cCredential == '' || cred.w3cCredential == 'vc') {
        continue;
      }
      if (cred.plaintextCredential == '') {
        var vc = VerifiableCredential.fromJson(cred.w3cCredential);
        if (vc.type.contains('ContextCredential')) {
          _wallet.storeConfigEntry(
              'contextId_${vc.credentialSubject['contextId']}', vc.id!);
          if (vc.type.contains('PaymentContext')) {
            paymentCredentials.add(vc);
            _updateLastThreePayments(vc.id!);
            if (vc.credentialSubject['paymentType'] == 'SimulatedPayment') {
              getFakeBalance(vc.id!);
            } else {
              getLnBalance(vc.id!);
            }
          }
          contextCredentials.add(vc);
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

    // sort contexts by date
    contextCredentials.sort((a, b) {
      if (a.issuanceDate.isAfter(b.issuanceDate)) {
        return 1;
      } else if (a.issuanceDate.isBefore(b.issuanceDate)) {
        return -1;
      } else {
        return 0;
      }
    });

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

  List<VerifiableCredential> getCredentialsForContext(String contextId) {
    var entry = _wallet.getConfigEntry(contextId);
    if (entry != null) {
      var decoded = jsonDecode(entry) as List;
      var list = <VerifiableCredential>[];
      for (var id in decoded) {
        var credential = _wallet.getCredential(id);
        if (credential?.w3cCredential != null) {
          list.add(VerifiableCredential.fromJson(credential!.w3cCredential));
        }
      }
      return list;
    }
    return [];
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

  Future<String> newCredentialDid() async {
    return _wallet.getNextCredentialDID(KeyType.ed25519);
  }

  Credential? getCredential(String did) {
    return _wallet.getCredential(did);
  }

  void storeCredential(String vc, String hdPath,
      {String? newDid, KeyType keyType = KeyType.ed25519}) async {
    await _wallet.storeCredential(vc, '', hdPath,
        keyType: keyType, credDid: newDid);
    _buildCredentialList();
    var vcParsed = VerifiableCredential.fromJson(vc);
    var type = vcParsed.type
        .firstWhere((element) => element != 'VerifiableCredential');
    logger.d(type);
    if (type == 'ContextCredential') {
      // await restoreCredentialsOfContext(
      //     vcParsed.id!, vcParsed.credentialSubject['contextId']);
      // await _wallet.storeConfigEntry(vcParsed.id!, jsonEncode([]));
      _wallet.storeConfigEntry(
          'contextId_${vcParsed.credentialSubject['contextId']}', vcParsed.id!);
      if (_wallet.getConfigEntry(vcParsed.id!) == null) {
        await _wallet.storeConfigEntry(vcParsed.id!, jsonEncode([]));
      }
    } else {
      // search if the credential maybe belongs to a context
      for (var vcs in contextCredentials) {
        if (vcs.credentialSubject.containsKey('groupedTypes')) {
          List groupedTypes =
              vcs.credentialSubject['groupedTypes'].cast<String>();
          logger.d(groupedTypes);
          if (groupedTypes.contains(type)) {
            var old = jsonDecode(_wallet.getConfigEntry(vcs.id!)!) as List;
            var id = vcParsed.id ?? getHolderDidFromCredential(vc);
            if (id == '') {
              id = '${vcParsed.issuanceDate.toIso8601String()}$type';
            }
            old.add(id);
            logger.d(old);
            await _wallet.storeConfigEntry(vcs.id!, jsonEncode(old));
            await _wallet.storeConfigEntry('${id}_context', vcs.id!);
            storeExchangeHistoryEntry(vcs.id!, DateTime.now(), 'add',
                my_util.getTypeToShow(vcParsed.type));
          }
        } else if (vcs.credentialSubject.containsKey('contexttype')) {
          if (vcParsed.type.contains(vcs.credentialSubject['contexttype'])) {
            var old =
                jsonDecode(_wallet.getConfigEntry(vcs.id!) ?? '[]') as List;
            var id = vcParsed.id ?? getHolderDidFromCredential(vc);
            if (id == '') {
              id = '${vcParsed.issuanceDate.toIso8601String()}$type';
            }
            old.add(id);
            logger.d(old);
            await _wallet.storeConfigEntry(vcs.id!, jsonEncode(old));
            await _wallet.storeConfigEntry('${id}_context', vcs.id!);
            storeExchangeHistoryEntry(vcs.id!, DateTime.now(), 'add',
                my_util.getTypeToShow(vcParsed.type));
          }
        }
      }
    }
    await checkValiditySingle(vcParsed);
    notifyListeners();
  }

  Future<String> getContextDid(String contextId) async {
    return _wallet.getConfigEntry('contextId_$contextId') ??
        await newCredentialDid();
  }

  // Future<void> restoreCredentialsOfContext(
  //     String newContextDid, String contextId) async {
  //   var oldContextDid = _wallet.getConfigEntry('contextId_$contextId');
  //   logger.d(oldContextDid);
  //   logger.d(newContextDid);
  //   if (oldContextDid != null) {
  //     var oldCredList =
  //         jsonDecode(_wallet.getConfigEntry(oldContextDid) ?? '[]');
  //     logger.d(oldCredList);
  //     for (var entry in oldCredList) {
  //       await _wallet.storeConfigEntry('${entry}_context', newContextDid);
  //     }
  //     await _wallet.storeConfigEntry(newContextDid, jsonEncode(oldCredList));
  //   }
  //   await _wallet.storeConfigEntry('contextId_$contextId', newContextDid);
  // }

  VerifiableCredential? getContextForCredential(String credentialId) {
    var contextId = _wallet.getConfigEntry('${credentialId}_context');
    if (contextId != null) {
      var contextCred = getCredential(contextId);
      if (contextCred != null && contextCred.w3cCredential.isNotEmpty) {
        return VerifiableCredential.fromJson(contextCred.w3cCredential);
      }
    }
    return null;
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
      var vc = VerifiableCredential.fromJson(cred.w3cCredential);
      if (vc.type.contains('ContextCredential')) {
        var contextId = vc.credentialSubject['contextId'];
        if (contextId != null) {
          var existing = getExistingContextIds();
          existing.remove(contextId);
          _wallet.storeConfigEntry('existingContexts', jsonEncode(existing));
        }

        var hdPath = cred.hdPath;
        await _wallet.storeCredential('', '', hdPath,
            keyType: KeyType.ed25519, credDid: null);

        // if (vc.credentialSubject['name'] == 'Kundenkarten') {
        //   _hasMemberCardContext = false;
        //   _wallet.deleteConfigEntry('hasMemberCardContext');
        // }
      } else {
        await _wallet.deleteCredential(credDid);
        await _wallet.deleteExchangeHistory(credDid);
        // await _wallet.deleteConfigEntry(credDid);
      }
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

  void addRelayedDid(String did) async {
    relayedDids.add(did);
    await wallet.storeConfigEntry('relayedDids', jsonEncode(relayedDids));
  }

  void removeRelayedDid(String did) async {
    relayedDids.remove(did);
    await wallet.storeConfigEntry('relayedDids', jsonEncode(relayedDids));
  }

  void checkRelay(Timer t) async {
    if (isOpen()) {
      // var connectionDids = allConnections();
      for (var did in relayedDids) {
        var serverAnswer = await get(Uri.parse('$relay/get/$did'));
        if (serverAnswer.statusCode == 200) {
          List messages = jsonDecode(serverAnswer.body);
          for (var m in messages) {
            local.handleDidcommMessage(jsonEncode(m));
          }
        }
      }
    }
  }

  Future<void> addContextIds(List<String> id) async {
    var existing = _wallet.getConfigEntry('existingContexts');
    var existingList = [];
    if (existing != null) {
      existingList = jsonDecode(existing).cast<String>();
    }

    existingList.addAll(id);
    _wallet.storeConfigEntry(
        'existingContexts', jsonEncode(existingList.toSet().toList()));
  }

  List<String> getExistingContextIds() {
    var entry = _wallet.getConfigEntry('existingContexts');
    if (entry != null) {
      return jsonDecode(entry).cast<String>();
    } else {
      return [];
    }
  }

  Future<void> addMemberCard(Map<String, String> subject) async {
    if (!getExistingContextIds().contains('5')) {
      var res = await get(Uri.parse('$contextEndpoint&contextid=5'));
      await issueContext(this, jsonDecode(res.body), '5');
      //await issueMemberCardContext(this);
      // _hasMemberCardContext = true;
      // await _wallet.storeConfigEntry('hasMemberCardContext', 'true');
    }

    var did = await newCredentialDid();
    var storage = getCredential(did);
    var vc = VerifiableCredential(
        context: [credentialsV1Iri, schemaOrgIri],
        issuer: did,
        issuanceDate: DateTime.now(),
        type: ['HidyContextKundenkarten', 'MemberCard'],
        credentialSubject: {'id': did, ...subject});

    var signed = await signCredential(_wallet, vc.toJson());
    storeCredential(signed, storage!.hdPath);
    wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
  }

  WalletStore get wallet => _wallet;
}

enum SortingType { dateUp, dateDown, typeUp, typeDown }

enum RevocationState { valid, expired, suspended, revoked, unknown }
