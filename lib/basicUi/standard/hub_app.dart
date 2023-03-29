import 'package:flutter/material.dart';

class HubApp extends StatelessWidget {
  const HubApp(
      {super.key,
      required this.onTap,
      required this.icon,
      required this.label});

  final void Function() onTap;
  final ImageProvider icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // return an app icon with a logo and text beneath it
    return InkWell(
      onTap: () => onTap(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              // solid black border
              border: Border.all(
                color: Colors.black,
                width: 3,
              ),
            ),
            child: Center(
                child: Image(
              image: icon,
              width: 40,
              height: 40,
            )),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
