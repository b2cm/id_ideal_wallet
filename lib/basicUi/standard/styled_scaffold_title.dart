import 'package:flutter/material.dart';

class StyledScaffoldTitle extends StatelessWidget {
  const StyledScaffoldTitle(
      {super.key,
      required this.title,
      required this.scanOnTap,
      required this.child,
      this.footerButtons});

  final String title;
  final void Function() scanOnTap;
  final Widget child;
  final List<Widget>? footerButtons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.black, //change your color here
        ),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(title, style: const TextStyle(color: Colors.black)),
        actions: [
          InkWell(
              onTap: () => scanOnTap(),
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Image(
                    image: AssetImage("assets/icons/scan-qr-solid.png"),
                    height: 22,
                    width: 22),
              )),
        ],
      ),
      // padding with red background
      body: Container(
          margin: const EdgeInsets.only(left: 10, right: 10, top: 10),
          child: child),
      // padding only left and right
      persistentFooterButtons: footerButtons,
    );
  }
}
