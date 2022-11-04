import 'dart:async';
import 'dart:convert';

import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';

import '../functions/util.dart' as my_util;

class WalletProvider extends ChangeNotifier {
  final WalletStore _wallet;
  String qrData = '';
  late Timer t;

  WalletProvider(String walletPath) : _wallet = WalletStore(walletPath) {
    t = Timer.periodic(const Duration(seconds: 10), checkRelay);
  }

  void openWallet() async {
    await my_util.openWallet(_wallet);
    if (!_wallet.isInitialized()) {
      _wallet.initialize();
      _wallet.initializeIssuer(KeyType.ed25519);
    }

    notifyListeners();
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

  void storeCredential(String vc, String hdPath) async {
    await _wallet.storeCredential(vc, '', hdPath, keyType: KeyType.ed25519);
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
