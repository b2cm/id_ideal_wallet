import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class SearchNewAbo extends StatefulWidget {
  const SearchNewAbo({super.key});

  @override
  SearchNewAboState createState() => SearchNewAboState();
}

class SearchNewAboState extends State<SearchNewAbo> {
  bool searching = true;
  List<AboData> toShow = [];

  @override
  void initState() {
    super.initState();
    searchAbos();
  }

  Future<void> searchAbos() async {
    var inAbo =
        Provider.of<WalletProvider>(context, listen: false).aboList.map((e) {
      return e.getComparableUrl();
    }).toList();

    var res = await get(Uri.parse(applicationEndpoint));
    List<AboData> available = [];
    if (res.statusCode == 200) {
      List dec = jsonDecode(res.body);
      available = dec.map((e) => AboData.fromJson(e)).toList();
    }

    toShow = [];

    if (available.isNotEmpty) {
      for (var entry in available) {
        if (!inAbo.contains(entry.getComparableUrl())) {
          toShow.add(entry);
        }
      }
    }

    setState(() {
      searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
      title: AppLocalizations.of(context)!.newAppTitle,
      child: searching
          ? const Center(child: CircularProgressIndicator())
          : toShow.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.newAppNote))
              : ListView.separated(
                  itemCount: toShow.length,
                  itemBuilder: (context, index) {
                    var e = toShow[index];
                    return ListTile(
                      leading: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.15,
                        height: MediaQuery.of(context).size.width * 0.15,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                          child: CachedImage(
                            key: UniqueKey(),
                            imageUrl: e.pictureUrl,
                            placeholder: e.name,
                          ),
                        ),
                      ),
                      title: Text(e.name),
                      subtitle: Text('Beschreibung'),
                      trailing: ElevatedButton(
                          onPressed: () {
                            Provider.of<WalletProvider>(context, listen: false)
                                .addAbo(e);
                            toShow.removeAt(index);
                            setState(() {});
                          },
                          child: Text('Holen')),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(
                      height: 7,
                    );
                  },
                ),
    );
  }
}
