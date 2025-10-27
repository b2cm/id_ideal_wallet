import 'package:flutter/material.dart';

class StyledScaffoldTitle extends StatelessWidget {
  const StyledScaffoldTitle(
      {super.key,
      required this.title,
      required this.child,
      this.footerButtons,
      this.appBarActions,
      this.fab,
      this.useBackSwipe = true,
      this.leading = false});

  final dynamic title;
  final Widget child;
  final FloatingActionButton? fab;
  final List<Widget>? footerButtons;
  final List<Widget>? appBarActions;
  final bool useBackSwipe;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: leading
            ? IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
      floatingActionButton: fab,
    );
  }
}
