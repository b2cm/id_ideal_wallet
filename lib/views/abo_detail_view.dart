import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';

import '../functions/util.dart';

class AboDetailView extends StatefulWidget {
  final AboData abo;

  const AboDetailView({super.key, required this.abo});

  @override
  AboDetailViewState createState() => AboDetailViewState();
}

class AboDetailViewState extends State<AboDetailView> {
  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: Text(widget.abo.name),
      child: Column(
        children: [
          Text('Beschreibung'),
          Text('Lorem ipsum dolor sit...'),
          Row(
            children: [],
          )
        ],
      ),
    );
  }
}
