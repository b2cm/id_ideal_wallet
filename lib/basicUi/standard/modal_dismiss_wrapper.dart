import 'package:flutter/material.dart';

class ModalDismissWrapper extends StatelessWidget {
  const ModalDismissWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: child),
      // padding only bottom 30px
      Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Center(
            child: ClipOval(
              child: Material(
                color: Colors.grey[300], // Button color
                child: InkWell(
                  splashColor: Colors.red, // Splash color
                  onTap: () {},
                  child: SizedBox(
                      width: 46,
                      height: 46,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      )),
                ),
              ),
            ),
          ))
    ]);
  }
}
