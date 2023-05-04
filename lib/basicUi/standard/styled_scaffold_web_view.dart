import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/main.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';

class StyledScaffoldWebView extends StatelessWidget {
  const StyledScaffoldWebView({
    super.key,
    required this.title,
    required this.backOnTap,
    required this.reloadOnTap,
    required this.child,
  });

  final String title;
  final void Function() backOnTap;
  final void Function() reloadOnTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Row(
          children: [
            InkWell(
                onTap: backOnTap,
                child: const Icon(Icons.arrow_back, size: 30)),
          ],
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black, //change your color here
        ),
        title: Text(title, style: const TextStyle(color: Colors.black)),
        actions: [
          InkWell(
              onTap: reloadOnTap, child: const Icon(Icons.refresh, size: 30)),
          const SizedBox(
            width: 5,
          ),
          InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.close,
                size: 30,
              )),
          const SizedBox(
            width: 5,
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.co_present), label: 'Credentials'),
          BottomNavigationBarItem(
              icon: Image(
                  image: AssetImage("assets/icons/scan-qr-solid.png"),
                  height: 30,
                  width: 30),
              label: 'Scannen'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
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
