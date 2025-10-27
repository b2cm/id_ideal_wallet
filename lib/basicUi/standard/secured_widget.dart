import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SecuredWidget extends StatefulWidget {
  final Widget child;

  const SecuredWidget({
    super.key,
    required this.child,
  });

  @override
  SecuredWidgetState createState() => SecuredWidgetState();
}

class SecuredWidgetState extends State<SecuredWidget> {
  void onWillPop(bool didPop, Object? o) {
    if (didPop) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(30.0),
        ),
      ),
      backgroundColor: Colors.black.withAlpha(170),
      behavior: SnackBarBehavior.floating,
      content: Text(AppLocalizations.of(context)!.cancelWarning),
    ));
    return;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false, onPopInvokedWithResult: onWillPop, child: widget.child);
  }
}
