import 'package:flutter/material.dart';

class StyledScaffoldWebView extends StatelessWidget {
  const StyledScaffoldWebView({
    super.key,
    required this.title,
    required this.backOnTap,
    required this.reloadOnTap,
    this.abo,
    required this.child,
  });

  final String title;
  final void Function() backOnTap;
  final void Function() reloadOnTap;
  final void Function()? abo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   leading: Row(
      //     children: [
      //       InkWell(
      //           onTap: backOnTap,
      //           child: const Icon(Icons.arrow_back, size: 40)),
      //     ],
      //   ),
      //   title: Text(title),
      // actions: [
      //   InkWell(
      //       onTap: reloadOnTap, child: const Icon(Icons.refresh, size: 40)),
      //   const SizedBox(
      //     width: 5,
      //   ),
      //   InkWell(
      //       onTap: () =>
      //           Navigator.of(context).popUntil((route) => route.isFirst),
      //       child: const Icon(
      //         Icons.close,
      //         size: 40,
      //       )),
      //   const SizedBox(
      //     width: 5,
      //   ),
      // ],
      // ),
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: abo != null
          ? FloatingActionButton.extended(
              onPressed: abo,
              icon: const Icon(Icons.add),
              isExtended: true,
              label: const Text('Abonieren'),
            )
          : null,
      // bottomNavigationBar: BottomNavigationBar(
      //   selectedItemColor: Colors.black,
      //   unselectedItemColor: Colors.black,
      //   items: [
      //     const BottomNavigationBarItem(
      //         icon: Icon(Icons.co_present), label: 'Credentials'),
      //     BottomNavigationBarItem(
      //         icon: const Icon(
      //           Icons.qr_code_scanner_sharp,
      //           size: 30,
      //         ),
      //         label: AppLocalizations.of(context)!.scan),
      //     const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      //   ],
      //   currentIndex: 1,
      //   onTap: (index) {
      //     switch (index) {
      //       case 0:
      //         Navigator.of(context).pushReplacement(MaterialPageRoute(
      //             builder: (context) => const CredentialPage(
      //                   initialSelection: 'all',
      //                 )));
      //         break;
      //       case 1:
      //         Navigator.of(context).push(
      //             MaterialPageRoute(builder: (context) => const QrScanner()));
      //         break;
      //       case 2:
      //         Navigator.of(context).popUntil((route) => route.isFirst);
      //         break;
      //     }
      //   },
      // ),
    );
  }
}
