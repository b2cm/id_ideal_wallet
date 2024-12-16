import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/functions/util.dart';

class RateSubApp extends StatefulWidget {
  final AboData abo;

  const RateSubApp({super.key, required this.abo});

  @override
  State<StatefulWidget> createState() => RateSubAppState();
}

class RateSubAppState extends State<RateSubApp> {
  int initialRating = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.1,
            height: MediaQuery.of(context).size.width * 0.1,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(4),
              ),
              child: CachedImage(
                key: UniqueKey(),
                imageUrl: widget.abo.pictureUrl,
                placeholder: widget.abo.name,
              ),
            ),
          ),
          Text(widget.abo.name,
              style: Theme.of(context).primaryTextTheme.headlineLarge)
        ]),
        const SizedBox(
          height: 10,
        ),
        Text('Bewerte die Anwendung, indem Du die Sterne antippst'),
        const SizedBox(
          height: 10,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            var j = initialRating;
            return InkWell(
              key: UniqueKey(),
              onTap: () {
                setState(() {
                  initialRating = i + 1;
                });
              },
              child: Icon(
                i <= j - 1 ? Icons.star : Icons.star_border,
                size: 45,
              ),
            );
          }),
        ),
        const SizedBox(
          height: 10,
        ),
        ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Bewerten'))
      ]),
    );
  }
}
