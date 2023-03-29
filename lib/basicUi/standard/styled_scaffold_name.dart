import 'package:flutter/material.dart';

class StyledScaffoldName extends StatelessWidget {
  const StyledScaffoldName(
      {super.key,
      required this.name,
      required this.nameOnTap,
      required this.scanOnTap,
      required this.child,
      this.footerButtons});

  final String name;
  final void Function() nameOnTap;
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
        centerTitle: false,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: InkWell(
            onTap: () => nameOnTap(),
            child: Row(children: [
              const Image(
                  image: AssetImage("assets/icons/circle-user-regular.png"),
                  height: 24,
                  width: 24),
              Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child:
                      Text(name, style: const TextStyle(color: Colors.black))),
            ])),
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
      // padding with no clipping behaviour
      body: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, top: 10),
        child: child,
      ),
      // padding only left and right
      persistentFooterButtons: footerButtons,
    );
  }
}
