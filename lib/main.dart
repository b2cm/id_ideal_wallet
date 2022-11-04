import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_detail.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:ln_wallet/ln_wallet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  runApp(ChangeNotifierProvider(
    create: (context) => WalletProvider(appDocumentDir.path),
    child: const App(),
  ));
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(context) {
    return MaterialApp(navigatorKey: navigatorKey, home: const MainPage());
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool isCred = true;

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
    return StyledScaffhold(
      name: 'Max Mustermann',
      nameOnTap: () {},
      scanOnTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const QrScanner()));
      },
      child: isCred
          ? const CredentialOverview()
          : const LnWalletMainPage(title: 'Lightning wallet'),
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

class CredentialOverview extends StatelessWidget {
  const CredentialOverview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (context, wallet, child) {
      if (wallet.isOpen()) {
        var allCreds = wallet.allCredentials().values.toList();
        return ListView.builder(
            padding: const EdgeInsets.only(bottom: 5),
            itemCount: allCreds.length,
            itemBuilder: (context, index) {
              var cred = allCreds[index].w3cCredential;
              if (cred != '') {
                return CredentialCard(
                    credential: VerifiableCredential.fromJson(cred));
              } else {
                return const SizedBox(
                  height: 0,
                );
              }
            });
      } else {
        wallet.openWallet();
        return const Center(
          child: Text('Wallet Öffnen'),
        );
      }
    });
  }
}

class CredentialCard extends StatelessWidget {
  final VerifiableCredential credential;

  const CredentialCard({Key? key, required this.credential}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => CredentialDetailView(credential: credential))),
      child: IdCard(
          cardTitle: credential.type
              .firstWhere((element) => element != 'VerifiableCredential'),
          subjectName:
              '${credential.credentialSubject['givenName'] ?? ''} ${credential.credentialSubject['familyName'] ?? ''}',
          bottomLeftText: '',
          bottomRightText: ''),
    );
  }
}
