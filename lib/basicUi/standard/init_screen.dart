import 'package:flutter/material.dart';

class InitScreen extends StatelessWidget {
  const InitScreen({super.key, required this.addCredentialButtonOnTap});

  final void Function() addCredentialButtonOnTap;

  @override
  Widget build(BuildContext context) {
    // return a full screen container with white background, a heading in red, a subheading in black a picture and a button in red and a button in gray, below that the text "Support" in red underlined
    return Scaffold(
        body: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // heading
              const Text(
                'Appʸ',
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              // subheading
              const Text(
                'wallet',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              // picture
              Container(
                padding: const EdgeInsets.all(15),
                child: const Image(
                  image: AssetImage('assets/images/undraw_agree_re_hor9.png',
                      package: "id_wallet_design"),
                  width: 300,
                  height: 300,
                ),
              ),
              // centered text
              const Text(
                'Füge dein erstes Credential hinzu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              // rounded red button
              const SizedBox(height: 20),
              InkWell(
                onTap: () => addCredentialButtonOnTap(),
                child: Container(
                  margin: const EdgeInsets.all(15),
                  width: 300,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: const Center(
                    child: Text(
                      'Credential hinzufügen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ])));
  }
}
