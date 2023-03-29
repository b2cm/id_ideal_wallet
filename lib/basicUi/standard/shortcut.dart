import 'package:flutter/material.dart';

class Shortcut extends StatelessWidget {
  const Shortcut(
      {super.key, required this.onTap, required this.icon, required this.text});

  final void Function() onTap;
  final ImageProvider icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    // return a full width container with the icon on the left, and the text with ellipsis in case of too long text, white background, rounded corners, and box shadow
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          // gray border
          border:
              Border.all(color: const Color.fromARGB(255, 209, 209, 209), width: 2),
        ),
        child: Row(
          children: [
            Image(
              image: icon,
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
