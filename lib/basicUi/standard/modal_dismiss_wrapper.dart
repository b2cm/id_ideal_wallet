import 'dart:async';

import 'package:flutter/material.dart';

class ModalDismissWrapper extends StatefulWidget {
  const ModalDismissWrapper({super.key, required this.child});

  final Widget child;

  @override
  ModalDismissWrapperState createState() => ModalDismissWrapperState();
}

class ModalDismissWrapperState extends State<ModalDismissWrapper> {
  late Timer end;

  @override
  void initState() {
    super.initState();

    end = Timer.periodic(const Duration(seconds: 2), (t) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        t.cancel();
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    end.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
