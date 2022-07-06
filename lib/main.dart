import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/util.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmpp_stone/xmpp_stone.dart' as xmpp;

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return FutureBuilder(
        future: getApplicationDocumentsDirectory(),
        builder: (context, AsyncSnapshot<Directory> snapshot) {
          if (snapshot.hasData) {
            return MaterialApp(
                home: MainPage(wallet: WalletStore(snapshot.data!.path)));
          } else {
            return const MaterialApp(
              home: Waiting(),
            );
          }
        });
  }
}

class Waiting extends StatelessWidget {
  const Waiting({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lade Wallet'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final WalletStore wallet;
  const MainPage({Key? key, required this.wallet}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();

  static void repaint(BuildContext context) {
    _MainPageState? state = context.findAncestorStateOfType<_MainPageState>();
    print(state);
    state?._repaint();
  }
}

class _MainPageState extends State<MainPage> implements xmpp.MessagesListener {
  late Future<bool> _initFuture;
  late xmpp.Connection _connection;
  bool isScanner = false;
  late Timer poller;

  @override
  initState() {
    super.initState();
    _initFuture = _init();
    var userAtDomain = 'testuser@localhost';
    var password = 'passwort';
    var jid = xmpp.Jid.fromFullJid(userAtDomain);
    var account = xmpp.XmppAccountSettings(
        userAtDomain, jid.local, jid.domain, password, 5222,
        resource: 'xmppstone');
    _connection = xmpp.Connection(account);
  }

  void _repaint() {
    setState(() {});
  }

  Future<void> _timerFunction(Timer t) async {
    if (widget.wallet.isWalletOpen()) {
      var connectionDids = widget.wallet.getAllConnections();
      for (var did in connectionDids.keys.toList()) {
        var serverAnswer =
            await get(Uri.parse('http://localhost:8888/get/$did'));
        if (serverAnswer.statusCode == 200) {
          List messages = jsonDecode(serverAnswer.body);
          for (var m in messages) {
            handleDidcommMessage(widget.wallet, jsonEncode(m), context,
                    xmpp.MessageHandler.getInstance(_connection))
                .then((value) {
              if (value) setState(() {});
            });
          }
        }
      }
    }
  }

  Future<bool> _init() async {
    if (await openWallet(widget.wallet)) {
      if (!widget.wallet.isInitialized()) {
        var m = await widget.wallet.initialize(
            mnemonic:
                'female exotic side crack letter mass payment winner special close endless swamp');
        print(m);
      }

      poller = Timer.periodic(const Duration(seconds: 15), _timerFunction);
      //connectXmpp();

      return true;
    } else {
      return false;
    }
  }

  Future<void> connectXmpp() async {
    _connection.connect();
    _connection.authenticating();
    //xmpp.MessagesListener messagesListener = ExampleMessagesListener(
    //    context, xmpp.MessageHandler.getInstance(_connection), widget.wallet);
    ExampleConnectionStateChangedListener(_connection, this);
    var presenceManager = xmpp.PresenceManager.getInstance(_connection);
    presenceManager.subscriptionStream.listen((streamEvent) {
      if (streamEvent.type == xmpp.SubscriptionEventType.REQUEST) {
        print('Accepting presence request');
        presenceManager.acceptSubscription(streamEvent.jid);
      }
    });
  }

  Widget _buildCredentialOverview() {
    var allCreds = widget.wallet.getAllCredentials();
    List<Widget> credViews = [];
    for (var cred in allCreds.values) {
      if (cred.w3cCredential != null && cred.w3cCredential != '') {
        credViews.add(_buildCredentialCard(cred.w3cCredential));
      }
    }
    return SingleChildScrollView(child: Column(children: credViews));
  }

  Widget _buildCredentialCard(String credential) {
    var asVc = VerifiableCredential.fromJson(credential);
    List<Widget> content = [
      Text(asVc.type.last,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(
        height: 10,
      )
    ];
    var additional = buildCredSubject(asVc.credentialSubject);
    content += additional;
    return Card(
      child: Column(
        children: content,
      ),
    );
  }

  Widget _buildScanner() {
    return MobileScanner(
        allowDuplicates: false,
        onDetect: (barcode, args) {
          if (barcode.rawValue != null) {
            final String code = barcode.rawValue!;
            debugPrint('Barcode found! $code');
            isScanner = false;
            handleDidcommMessage(widget.wallet, code, context,
                xmpp.MessageHandler.getInstance(_connection));
            setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht'),
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!) {
              return isScanner ? _buildScanner() : _buildCredentialOverview();
            } else {
              return const Text('beim Öffnen ging was schief');
            }
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            isScanner = true;
            setState(() {});
          },
          child: const Icon(Icons.qr_code)),
    );
  }

  @override
  void onNewMessage(xmpp.MessageStanza? message) {
    if (message != null) {
      if (message.body != null) {
        print(message.body);
        handleDidcommMessage(widget.wallet, message.body!, context,
                xmpp.MessageHandler.getInstance(_connection))
            .then((value) {
          if (value) setState(() {});
        });
      }
    }
  }
}

class ExampleConnectionStateChangedListener
    implements xmpp.ConnectionStateChangedListener {
  late xmpp.Connection _connection;
  late xmpp.MessagesListener _messagesListener;

  late StreamSubscription<String> subscription;

  ExampleConnectionStateChangedListener(
      xmpp.Connection connection, xmpp.MessagesListener messagesListener) {
    _connection = connection;
    _messagesListener = messagesListener;
    _connection.connectionStateStream.listen(onConnectionStateChanged);
  }

  @override
  void onConnectionStateChanged(xmpp.XmppConnectionState state) {
    print(state);
    if (state == xmpp.XmppConnectionState.Ready) {
      print('Connected');
      var vCardManager = xmpp.VCardManager(_connection);
      vCardManager.getSelfVCard().then((vCard) {
        if (vCard != null) {
          print('Your info' + vCard.buildXmlString());
        }
      });
      var messageHandler = xmpp.MessageHandler.getInstance(_connection);
      var rosterManager = xmpp.RosterManager.getInstance(_connection);
      messageHandler.messagesStream.listen(_messagesListener.onNewMessage);
      sleep(const Duration(seconds: 1));
      var receiver = 'testuser2@localhost';
      var receiverJid = xmpp.Jid.fromFullJid(receiver);
      rosterManager.addRosterItem(xmpp.Buddy(receiverJid)).then((result) {
        if (result.description != null) {
          print('add roster');
        }
      });
      sleep(const Duration(seconds: 1));
      vCardManager.getVCardFor(receiverJid).then((vCard) {
        if (vCard != null) {
          print('Receiver info' + vCard.buildXmlString());
        }
      });
      var presenceManager = xmpp.PresenceManager.getInstance(_connection);
      presenceManager.presenceStream.listen(onPresence);
    }
  }

  void onPresence(xmpp.PresenceData event) {
    print(event);
  }
}

List<Widget> buildCredSubject(Map<String, dynamic> subject, [String? before]) {
  List<Widget> children = [];
  subject.forEach((key, value) {
    if (key != 'id') {
      if (value is Map<String, dynamic>) {
        List<Widget> subs = buildCredSubject(value, key);
        children.addAll(subs);
      } else {
        children.add(Text('${before != null ? '$before.' : ''}$key: $value'));
      }
    }
  });
  return children;
}
