import 'dart:async';
import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/lightning_utils.dart';
import 'package:id_wallet_design/id_wallet_design.dart';

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  bool _authRunning = false;
  String qrData = '';
  late Timer t;
  Timer? paymentTimer;
  String? lnAuthToken;
  int balance = -1;
  SortingType sortingType = SortingType.dateDown;
  List<ExchangeHistoryEntry> lastPayments = [];
  List<VerifiableCredential> credentials = [];

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

      var login = wallet.getConfigEntry('ln_login');
      if (login == null) {
        // var account = await createAccount();
        // await wallet.storeConfigEntry('ln_login', account['ln_login']!);
        // await wallet.storeConfigEntry('ln_password', account['ln_password']!);

        await wallet.storeConfigEntry('ln_login', '5a9ec88b1677a8e4a14e');
        await wallet.storeConfigEntry('ln_password', '968394acb0ceeaf993c8');
      }

      login = wallet.getConfigEntry('ln_login');
      var password = wallet.getConfigEntry('ln_password');

      // lnAuthToken = await getLnAuthToken(login!, password!);
      // balance = await getBalance(lnAuthToken!);

      lnAuthToken = 'abhg';
      balance = 10000;

      _updateLastThreePayments();

      _authRunning = false;
      notifyListeners();
    }
  }

  void simulatePay(String amount) {
    balance -= int.parse(amount);
    notifyListeners();
  }

  void getLnBalance() async {
    balance = await getBalance(lnAuthToken!);
    notifyListeners();
  }

  void storePayment(String action, String otherParty,
      [List<String>? belongingCredentials]) async {
    _wallet.storeExchangeHistoryEntry('paymentHistory', DateTime.now(), action,
        otherParty, belongingCredentials);
    _updateLastThreePayments();
    //getLnBalance();
    notifyListeners();
  }

  void newPayment(String index, String memo, int amount) {
    paymentTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      var paid = await isInvoicePaid(index, lnAuthToken!);
      if (paid) {
        timer.cancel();
        storePayment('+$amount', memo == '' ? 'Lightning Invoice' : memo);
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
                      amount: "+$amount",
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

  void checkRelay(Timer t) async {
    if (isOpen()) {
      var connectionDids = allConnections();
      for (var did in connectionDids.keys.toList()) {
        var serverAnswer = await get(Uri.parse('$relay/get/$did'));
        if (serverAnswer.statusCode == 200) {
          List messages = jsonDecode(serverAnswer.body);
          for (var m in messages) {
            handleDidcommMessage(jsonEncode(m));
          }
        }
      }
    }
  }

  WalletStore get wallet => _wallet;
}

enum SortingType { dateUp, dateDown, typeUp, typeDown }
