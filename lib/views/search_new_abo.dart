import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

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
    try {
      var res = await get(Uri.parse(applicationEndpoint))
          .timeout(Duration(seconds: 120));
      List<AboData> available = [];
      if (res.statusCode == 200) {
        List dec = jsonDecode(res.body);
        available = dec.map((e) => AboData.fromJson(e)).toList();
      }

      toShow = available;
    } catch (_) {
      toShow = <AboData>[];
    }

    // if (available.isNotEmpty) {
    //   for (var entry in available) {
    //     if (!inAbo.contains(entry.getComparableUrl())) {
    //       toShow.add(entry);
    //     }
    //   }
    // }

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
                    var wallet =
                        Provider.of<WalletProvider>(context, listen: false);
                    var inAbo = wallet.aboList.map((e) {
                      return e.getComparableUrl();
                    });
                    var e = toShow[index];
                    return ListTile(
                      // TODO uncomment when details view is usable
                      // onTap: () => navigateClassic(AboDetailView(
                      //   abo: e,
                      //   isInAbo: inAbo.contains(e.getComparableUrl()),
                      // )),
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
                      //subtitle: Text('Beschreibung'),
                      trailing: inAbo.contains(e.getComparableUrl())
                          ? ElevatedButton(
                              onPressed: () {
                                loadWebview(e);
                              },
                              child: Text('Öffnen'))
                          : ElevatedButton(
                              onPressed: () {
                                Provider.of<WalletProvider>(context,
                                        listen: false)
                                    .addAbo(e);
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
