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

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  bool _authRunning = false;
  String qrData = '';
  late Timer t;
  Timer? paymentTimer;
  String? lnAdminKey;
  String? lnInKey;
  double balance = -1.0;
  SortingType sortingType = SortingType.dateDown;
  List<ExchangeHistoryEntry> lastPayments = [];
  List<VerifiableCredential> credentials = [];
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
        _wallet.initialize();
        _wallet.initializeIssuer(KeyType.ed25519);
      }

      _buildCredentialList();

      var lastCheck = _wallet.getConfigEntry('lastValidityCheckTime');
      if (lastCheck == null) {
        checkValidity();
      } else {
        lastCheckRevocation = DateTime.parse(lastCheck);
        if (DateTime.now().difference(lastCheckRevocation!) >=
            const Duration(days: 1)) {
          checkValidity();
        }
      }

      lnAdminKey = _wallet.getConfigEntry('lnAdminKey');
      lnInKey = _wallet.getConfigEntry('lnInKey');

      if (lnInKey != null) {
        getLnBalance();
      }

      _updateLastThreePayments();

      _authRunning = false;

      var relayedDidsEntry = wallet.getConfigEntry('relayedDids');
      if (relayedDidsEntry != null && relayedDidsEntry.isNotEmpty) {
        relayedDids = jsonDecode(relayedDidsEntry).cast<String>();
      }

      notifyListeners();
    }
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

  void simulatePay(String amount) {
    balance -= int.parse(amount);
    notifyListeners();
  }

  void getLnBalance() async {
    var a = await getBalance(lnInKey!);
    balance = a.toEuro();
    notifyListeners();
  }

  void storeLnAccount(Map<String, dynamic> accountData) async {
    var wallets = accountData['wallets'] as List;
    var w = wallets.first;
    lnAdminKey = w['adminkey'];
    lnInKey = w['inkey'];

    if (lnAdminKey == null || lnInKey == null) {
      throw Exception('AdminKey or inKey null - this should not happen');
      // Todo message to user
    }

    await _wallet.storeConfigEntry('lnAdminKey', lnAdminKey!);
    await _wallet.storeConfigEntry('lnInKey', lnInKey!);
    await _wallet.storeConfigEntry('lnDetails', jsonEncode(accountData));

    notifyListeners();
  }

  void storePayment(String action, String otherParty,
      [List<String>? belongingCredentials]) async {
    _wallet.storeExchangeHistoryEntry('paymentHistory', DateTime.now(), action,
        otherParty, belongingCredentials);
    _updateLastThreePayments();
    getLnBalance();
    notifyListeners();
  }

  void newPayment(String paymentHash, String memo, SatoshiAmount amount) {
    paymentTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      var paid = await isInvoicePaid(lnInKey!, paymentHash);
      logger.d(paymentHash);
      if (paid) {
        timer.cancel();
        storePayment('+${amount.toEuro().toStringAsFixed(2)}',
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

  void _updateLastThreePayments() {
    var payments = getAllPayments();
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
      lastPayments = payments;
    } else {
      lastPayments = [payments.first, payments[1], payments[2]];
    }
  }

  void _buildCredentialList() {
    credentials = [];
    var all = allCredentials();
    for (var cred in all.values) {
      if (cred.w3cCredential == '') {
        continue;
      }
      if (cred.plaintextCredential == '') {
        credentials.add(VerifiableCredential.fromJson(cred.w3cCredential));
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

  void changeSortingType(SortingType newType) {
    sortingType = newType;
    _buildCredentialList();
    notifyListeners();
  }

  List<ExchangeHistoryEntry> getAllPayments() {
    return _wallet.getExchangeHistoryEntriesForCredential('paymentHistory') ??
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
    await checkValiditySingle(VerifiableCredential.fromJson(vc));
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
