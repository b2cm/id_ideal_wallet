import 'dart:async';
import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart'
    as local;
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/views/add_context_credential.dart';

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  bool _authRunning = false;

  String qrData = '';

  late Timer t;
  SortingType sortingType = SortingType.dateDown;

  Map<String, List<ExchangeHistoryEntry>> lastPayments = {};
  Map<String, double> balance = {};
  Timer? paymentTimer;

  List<VerifiableCredential> credentials = [];
  List<VerifiableCredential> contextCredentials = [];
  List<VerifiableCredential> paymentCredentials = [];

  List<String> relayedDids = [];
  DateTime? lastCheckRevocation;
  Map<String, int> revocationState = {};

  WalletProvider(String walletPath) : _wallet = WalletStore(walletPath) {
    t = Timer.periodic(const Duration(seconds: 10), checkRelay);
  }

  void openWallet() async {
    if (!_authRunning) {
      _authRunning = true;
      await my_util.openWallet(_wallet);

      if (!_wallet.isInitialized()) {
        await _wallet.initialize();
        await _wallet.initializeIssuer(KeyType.ed25519);
      }

      await updateStorage();

      _buildCredentialList();

      if (contextCredentials.isEmpty) {
        await issueLNDWContextMittweida(this);
        await issueLNDWContextDresden(this);
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

      var relayedDidsEntry = wallet.getConfigEntry('relayedDids');
      if (relayedDidsEntry != null && relayedDidsEntry.isNotEmpty) {
        relayedDids = jsonDecode(relayedDidsEntry).cast<String>();
      }

      notifyListeners();
    }
  }

  String? getLnInKey(String paymentId) {
    return _wallet.getConfigEntry('lnInKey$paymentId');
  }

  String? getLnAdminKey(String paymentId) {
    return _wallet.getConfigEntry('lnInKey$paymentId');
  }

  Future<void> checkValiditySingle(VerifiableCredential vc,
      [bool notify = false]) async {
    var id = vc.id ?? getHolderDidFromCredential(vc.toJson());
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
    var a = await getBalance(getLnInKey(paymentId)!);
    balance[paymentId] = a.toEuro();
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

  void storeLnAccount(
      String paymentId, Map<String, dynamic> accountData) async {
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
        storePayment(paymentId, '+${amount.toEuro().toStringAsFixed(2)}',
            memo == '' ? 'Lightning Invoice' : memo);
        paymentTimer = null;
        showModalBottomSheet(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline: "Zahlung eingegangen",
                  success: true,
                  amount: CurrencyDisplay(
                      amount: "+${amount.toEuro().toStringAsFixed(2)}",
                      symbol: '€',
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
      paymentType = 'LightningPayment';
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

  void _buildCredentialList() {
    credentials = [];
    contextCredentials = [];
    paymentCredentials = [];

    var all = allCredentials();
    for (var cred in all.values) {
      if (cred.w3cCredential == '') {
        continue;
      }
      if (cred.plaintextCredential == '') {
        var vc = VerifiableCredential.fromJson(cred.w3cCredential);
        if (vc.type.contains('ContextCredential')) {
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
          credentials.add(vc);
        }
      } else {
        // TODO: merge w3c and Plaintext credential
      }
    }

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
          var typeA =
              a.type.firstWhere((element) => element != 'VerifiableCredential');
          var typeB =
              b.type.firstWhere((element) => element != 'VerifiableCredential');
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

  bool isOpen() {
    return _wallet.isWalletOpen();
  }

  DidcommConversation? getConversation(String id) {
    return _wallet.getConversationEntry(id);
  }

  Future<String> newConnectionDid() async {
    return _wallet.getNextConnectionDID(KeyType.x25519);
  }

  Future<String> newCredentialDid() async {
    return _wallet.getNextCredentialDID(KeyType.ed25519);
  }

  Credential? getCredential(String did) {
    return _wallet.getCredential(did);
  }

  void storeCredential(String vc, String hdPath, [String? newDid]) async {
    await _wallet.storeCredential(vc, '', hdPath,
        keyType: KeyType.ed25519, credDid: newDid);
    _buildCredentialList();
    var vcParsed = VerifiableCredential.fromJson(vc);
    var type = vcParsed.type
        .firstWhere((element) => element != 'VerifiableCredential');
    logger.d(type);
    if (type == 'ContextCredential') {
      await _wallet.storeConfigEntry(vcParsed.id!, jsonEncode([]));
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
          }
        }
      }
    }
    await checkValiditySingle(vcParsed);
    notifyListeners();
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

  void deleteCredential(String credDid) {
    _wallet.deleteCredential(credDid);
    _buildCredentialList();
    notifyListeners();
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

  WalletStore get wallet => _wallet;
}

enum SortingType { dateUp, dateDown, typeUp, typeDown }

enum RevocationState { valid, expired, suspended, revoked, unknown }
