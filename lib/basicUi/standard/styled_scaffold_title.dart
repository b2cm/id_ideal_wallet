import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/qr_scanner.dart';

class StyledScaffoldTitle extends StatelessWidget {
  const StyledScaffoldTitle(
      {super.key,
      required this.title,
      required this.child,
      this.currentlyActive,
      this.footerButtons,
      this.appBarActions,
      this.useBackSwipe = true});

  final dynamic title;
  final Widget child;
  final int? currentlyActive;
  final List<Widget>? footerButtons;
  final List<Widget>? appBarActions;
  final bool useBackSwipe;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // Swiping in right direction.
        if (details.delta.dx > 0) {}

        // Swiping in left direction.
        if (useBackSwipe && details.delta.dx < 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: title is String ? Text(title) : title,
          actions: appBarActions,
        ),
        // padding with red background
        body: Container(
            margin: const EdgeInsets.only(left: 10, right: 10, top: 0),
            child: child),
        // padding only left and right
        persistentFooterButtons: footerButtons,
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: currentlyActive == null
              ? Colors.black
              : Colors.greenAccent.shade700,
          unselectedItemColor: Colors.black,
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.co_present), label: 'Credentials'),
            BottomNavigationBarItem(
                icon: const Icon(
                  Icons.qr_code_scanner_sharp,
                  size: 30,
                ),
                label: AppLocalizations.of(context)!.scan),
            const BottomNavigationBarItem(
                icon: Icon(Icons.home), label: 'Home'),
          ],
          currentIndex: currentlyActive ?? 1,
          onTap: (index) {
            switch (index) {
              case 0:
                if (currentlyActive != 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const CredentialPage(
                            initialSelection: 'all',
                          )));

                  // currentlyActive != 2
                  //     ? Navigator.of(context).pushReplacement(MaterialPageRoute(
                  //         builder: (context) => const CredentialPage(
                  //               initialSelection: 'all',
                  //             )))
                  //     : Navigator.of(context).push(MaterialPageRoute(
                  //         builder: (context) => const CredentialPage(
                  //               initialSelection: 'all',
                  //             )));
                }
                break;
              case 1:
                if (currentlyActive != 1) {
                  currentlyActive == 0
                      ? Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (context) => const QrScanner()))
                      : Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const QrScanner()));
                }
                break;
              case 2:
                if (currentlyActive != 2) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
                break;
            }
          },
        ),
      ),
    );
  }
}
