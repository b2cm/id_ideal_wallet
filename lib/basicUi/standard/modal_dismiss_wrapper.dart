import 'dart:async';

import 'package:flutter/material.dart';

class ModalDismissWrapper extends StatefulWidget {
  const ModalDismissWrapper(
      {super.key, required this.child, this.closeSeconds = 2});

  final Widget child;
  final int closeSeconds;

  @override
  ModalDismissWrapperState createState() => ModalDismissWrapperState();
}

class ModalDismissWrapperState extends State<ModalDismissWrapper> {
  late Timer end;

  @override
  void initState() {
    super.initState();

    end = Timer.periodic(Duration(seconds: widget.closeSeconds), (t) {
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
