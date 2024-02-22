import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class SearchNewAbo extends StatefulWidget {
  const SearchNewAbo({super.key});

  @override
  SearchNewAboState createState() => SearchNewAboState();
}

class SearchNewAboState extends State<SearchNewAbo> {
  bool searching = true;
  List<Map<String, dynamic>> toShow = [];
  List<bool> checked = [];

  @override
  void initState() {
    super.initState();
    searchAbos();
  }

  Future<void> searchAbos() async {
    var inAbo = Provider.of<WalletProvider>(context, listen: false)
        .aboList
        .map((e) => e['url']!)
        .toList();

    var res = await get(Uri.parse(applicationEndpoint));
    List<Map<String, dynamic>> available = [];
    if (res.statusCode == 200) {
      List dec = jsonDecode(res.body);
      available = dec.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    toShow = [];
    checked = [];
    if (available.isNotEmpty) {
      for (var entry in available) {
        var asUri = Uri.parse(entry['url']);
        var toCheck = '${asUri.scheme}://${asUri.host}${asUri.path}';
        if (!inAbo.contains(toCheck)) {
          toShow.add(entry);
          checked.add(false);
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
      fab: !searching && toShow.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                var wallet =
                    Provider.of<WalletProvider>(context, listen: false);
                for (int i = 0; i < checked.length; i++) {
                  if (checked[i]) {
                    var entry = toShow[i];
                    wallet.addAbo(
                        entry['url'], entry['mainbgimg'], entry['name']);
                  }
                }
                Provider.of<NavigationProvider>(context, listen: false)
                    .goBack();
              },
              label: Text(AppLocalizations.of(context)!.add),
            )
          : null,
      child: searching
          ? const Center(child: CircularProgressIndicator())
          : toShow.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.newAppNote))
              : ListView.separated(
                  itemCount: toShow.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      trailing: Checkbox(
                        value: checked[index],
                        onChanged: (bool? value) {
                          if (value != null) {
                            setState(() {
                              checked[index] = value;
                            });
                          }
                        },
                      ),
                      leading: Container(
                          width: 100,
                          decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                  scale: 0.2,
                                  fit: BoxFit.cover,
                                  image:
                                      Image.network(toShow[index]['mainbgimg'])
                                          .image))),
                      title: Text(toShow[index]['name'] ?? ''),
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
