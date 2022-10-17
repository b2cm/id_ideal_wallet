import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x509b/x509.dart' as x509;

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
        var serverAnswer =
            await get(Uri.parse('http://localhost:8888/get/$did'));
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
        var m = await widget.wallet.initialize(
            mnemonic:
                'female exotic side crack letter mass payment winner special close endless swamp');
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
    return SingleChildScrollView(child: Column(children: credViews));
  }

  Widget _buildCredentialCard(String credential) {
    var asVc = VerifiableCredential.fromJson(credential);
    List<Widget> content = [
      Text(asVc.type.firstWhere((element) => element != 'VerifiableCredential'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(
        height: 10,
      )
    ];
    if (asVc.issuer is Map && asVc.issuer.containsKey('certificate')) {
      var certIt = x509.parsePem(
          '-----BEGIN CERTIFICATE-----\n${asVc.issuer['certificate']}\n-----END CERTIFICATE-----');
      var cert = certIt.first as x509.X509Certificate;

      var commonNameMap = cert.tbsCertificate.subject?.names.firstWhere(
          (element) =>
              element.containsKey(const x509.ObjectIdentifier([2, 5, 4, 3])),
          orElse: () => {
                const x509.ObjectIdentifier([2, 5, 4, 3]): ''
              });
      String commonName =
          commonNameMap![const x509.ObjectIdentifier([2, 5, 4, 3])];
      var orgMap = cert.tbsCertificate.subject?.names.firstWhere(
          (element) =>
              element.containsKey(const x509.ObjectIdentifier([2, 5, 4, 10])),
          orElse: () => {
                const x509.ObjectIdentifier([2, 5, 4, 10]): ''
              });
      String org = orgMap![const x509.ObjectIdentifier([2, 5, 4, 10])];
      if (org.isEmpty) {
        org = commonName;
      }
      content.add(Text('Verifizierter Aussteller: $org'));
      content.add(const SizedBox(
        height: 10,
      ));
    }
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
            handleDidcommMessage(widget.wallet, code, context);
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
