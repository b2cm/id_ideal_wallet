import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:ln_wallet/ln_wallet.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

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

class _MainPageState extends State<MainPage> {
  late Future<bool> _initFuture;
  bool isCred = true;
  bool isScanner = false;
  late Timer poller;

  @override
  initState() {
    super.initState();
    _initFuture = _init();
  }

  void _repaint() {
    setState(() {});
  }

  Future<void> _timerFunction(Timer t) async {
    if (widget.wallet.isWalletOpen()) {
      var connectionDids = widget.wallet.getAllConnections();
      for (var did in connectionDids.keys.toList()) {
        var serverAnswer = await get(Uri.parse('$relay/get/$did'));
        if (serverAnswer.statusCode == 200) {
          List messages = jsonDecode(serverAnswer.body);
          for (var m in messages) {
            handleDidcommMessage(widget.wallet, jsonEncode(m), context)
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
        var m = await widget.wallet.initialize();
        print(m);
      }

      poller = Timer.periodic(const Duration(seconds: 10), _timerFunction);

      return true;
    } else {
      return false;
    }
  }

  Widget _buildCredentialOverview() {
    var allCreds = widget.wallet.getAllCredentials();
    List<Widget> credViews = [];
    for (var cred in allCreds.values) {
      if (cred.w3cCredential != null && cred.w3cCredential != '') {
        credViews.add(_buildCredentialCard(cred.w3cCredential));
      }
    }
    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
            child: Column(
              children: credViews,
              crossAxisAlignment: CrossAxisAlignment.center,
            )));
  }

  Widget _buildCredentialCard(String credential) {
    var asVc = VerifiableCredential.fromJson(credential);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) =>
              CredentialDetailView(wallet: widget.wallet, credential: asVc))),
      child: buildCredentialCard(asVc),
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
            handleDidcommMessage(widget.wallet, code, context);
            setState(() {});
          }
        });
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text('Menü'),
          ),
          ListTile(
            title: const Text('Credential-Übersicht'),
            onTap: () {
              isCred = true;
              setState(() {});
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Lightning Wallet'),
            onTap: () {
              isCred = false;
              setState(() {});
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            isScanner ? const Text('QR-Code scannen') : const Text('Übersicht'),
        actions: isScanner
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: () {
                      isScanner = false;
                      setState(() {});
                    },
                    child: const Icon(Icons.close),
                  ),
                )
              ]
            : [],
      ),
      drawer: _buildDrawer(),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!) {
              return isScanner
                  ? _buildScanner()
                  : isCred
                      ? _buildCredentialOverview()
                      : const LnWalletMainPage(title: 'Lightning wallet');
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
      floatingActionButton: isScanner
          ? null
          : FloatingActionButton(
              onPressed: () {
                isScanner = true;
                setState(() {});
              },
              child: const Icon(Icons.qr_code)),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    poller.cancel();
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
