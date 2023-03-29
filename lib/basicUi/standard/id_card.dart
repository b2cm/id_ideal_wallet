import 'package:flutter/material.dart';

class IdCard extends StatelessWidget {
  const IdCard(
      {super.key,
      required this.cardTitle,
      required this.subjectName,
      required this.bottomLeftText,
      required this.bottomRightText,
      this.cardColor = const Color.fromARGB(255, 255, 86, 86),
      this.cardTitleColor = const Color.fromARGB(255, 255, 255, 255),
      this.backgroundColor = const Color.fromARGB(255, 233, 224, 200),
      this.subjectImage,
      this.backgroundImage,
      this.issuerIcon,
      this.borderColor = const Color.fromARGB(255, 122, 122, 122)});

  final Color cardColor;
  final String cardTitle;
  final Color cardTitleColor;
  final String subjectName;
  final ImageProvider? subjectImage;
  final Widget bottomLeftText;
  final Widget bottomRightText;
  final ImageProvider? backgroundImage;
  final ImageProvider? issuerIcon;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: 335 / 195,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 2),
            image: backgroundImage != null
                ? DecorationImage(
                    image: backgroundImage!,
                    fit: BoxFit.cover,
                    opacity: 0.25,
                  )
                : null,
          ),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        cardTitle,
                        style: TextStyle(
                          color: cardTitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    issuerIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Image(
                              image: issuerIcon!,
                              width: 32,
                              height: 32,
                            ))
                        : const SizedBox(
                            width: 0,
                          ),
                  ]),
                ),
                Flexible(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          subjectName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      subjectImage != null
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 6,
                                        color: Colors.grey,
                                        spreadRadius: 2)
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundImage: subjectImage,
                                ),
                              ),
                            )
                          : const SizedBox(
                              width: 0,
                            ),
                    ],
                  ),
                ),
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: bottomLeftText,
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: bottomRightText,
                    ),
                  ]),
                ),
              ]),
        ));
  }
}
