import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';

class StyledScaffoldTitle extends StatelessWidget {
  const StyledScaffoldTitle(
      {super.key,
      required this.title,
      required this.child,
      this.footerButtons});

  final String title;
  final Widget child;
  final List<Widget>? footerButtons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black, //change your color here
        ),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(title, style: const TextStyle(color: Colors.black)),
      ),
      // padding with red background
      body: Container(
          margin: const EdgeInsets.only(left: 10, right: 10, top: 10),
          child: child),
      // padding only left and right
      persistentFooterButtons: footerButtons,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.co_present), label: 'Credentials'),
          BottomNavigationBarItem(
              icon: const Image(
                  image: AssetImage("assets/icons/scan-qr-solid.png"),
                  height: 30,
                  width: 30),
              label: AppLocalizations.of(context)!.scan),
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        ],
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const CredentialPage()));
              break;
            case 1:
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const QrScanner()));
              break;
            case 2:
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainPage()));
              break;
          }
        },
      ),
    );
  }
}
