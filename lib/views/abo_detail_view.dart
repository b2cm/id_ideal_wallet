import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:provider/provider.dart';

import '../functions/util.dart';

class AboDetailView extends StatefulWidget {
  final AboData abo;
  final bool isInAbo;

  const AboDetailView({super.key, required this.abo, required this.isInAbo});

  @override
  AboDetailViewState createState() => AboDetailViewState();
}

class AboDetailViewState extends State<AboDetailView> {
  bool inAbo = false;

  @override
  void initState() {
    super.initState();
    inAbo = widget.isInAbo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: ListTile(
        title: Text(widget.abo.name,
            style: Theme.of(context).primaryTextTheme.headlineLarge),
        subtitle: Text('by Author'),
      )),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Flexible(
                  child: ListTile(
                title: Text('4 / 5',
                    style: Theme.of(context).primaryTextTheme.titleLarge),
                subtitle: StarRow(
                  rating: 4.0,
                ),
              )),
              Flexible(
                  child: ListTile(
                title: Text('500',
                    style: Theme.of(context).primaryTextTheme.titleLarge),
                subtitle: Text('Abonenten'),
              ))
            ],
          ),
          SizedBox(
            height: 10,
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Swiper(
              itemBuilder: (BuildContext context, int index) {
                return Image.network(
                  "https://via.placeholder.com/350x150",
                  fit: BoxFit.fill,
                );
              },
              itemCount: 3,
              viewportFraction: 0.8,
              scale: 0.9,
              loop: false,
              pagination: SwiperPagination(),
              //control: SwiperControl(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text('Beschreibung',
                style: Theme.of(context).primaryTextTheme.titleLarge),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Lorem ipsum dolor sit...'),
          ),
        ]),
      ),
      persistentFooterButtons: [
        ElevatedButton(
          onPressed: () {
            if (widget.isInAbo) {
              navigateClassic(WebViewWindow(
                initialUrl: widget.abo.url.replaceAll('wid=',
                    'wid=${Provider.of<WalletProvider>(context, listen: false).lndwId}'),
                title: widget.abo.name,
                iconUrl: widget.abo.pictureUrl,
              ));
            } else {
              Provider.of<WalletProvider>(context, listen: false)
                  .addAbo(widget.abo);
              setState(() {
                inAbo = true;
              });
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(45),
          ),
          child: Text(inAbo ? 'Öffnen' : 'Abonieren'),
        ),
      ],
    );
  }
}

class StarRow extends StatefulWidget {
  final double rating;

  const StarRow({
    super.key,
    required this.rating,
  });

  @override
  State<StatefulWidget> createState() => StarRowState();
}

class StarRowState extends State<StarRow> {
  double rating = 0;

  @override
  void initState() {
    super.initState();
    rating = widget.rating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (i) {
        var j = rating.round();
        return Icon(
          i <= j - 1 ? Icons.star : Icons.star_border,
        );
      }),
    );
  }
}
