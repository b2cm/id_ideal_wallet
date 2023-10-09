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
  Timer? end;

  @override
  void initState() {
    super.initState();

    if (widget.closeSeconds > 0) {
      end = Timer.periodic(Duration(seconds: widget.closeSeconds), (t) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          t.cancel();
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    end?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
