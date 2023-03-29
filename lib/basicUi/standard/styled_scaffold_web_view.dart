import 'package:flutter/material.dart';

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
    );
  }
}
