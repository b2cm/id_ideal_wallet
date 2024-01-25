import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

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
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: title is String
              ? Text(
                  title,
                  style: Theme.of(context).primaryTextTheme.headlineLarge,
                )
              : title,
          actions: appBarActions,
        ),
        body: Container(
            margin: const EdgeInsets.only(left: 10, right: 10, top: 0),
            child: child),
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
                  context.go('/credentials?initialSelection=all');
                }
                break;
              case 1:
                if (currentlyActive != 1) {
                  context.go('/scanner');
                }
                break;
              case 2:
                if (currentlyActive != 2) {
                  context.go('/');
                }
                break;
            }
          },
        ),
      ),
    );
  }
}
