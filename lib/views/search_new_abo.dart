import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:provider/provider.dart';

class SearchNewAbo extends StatefulWidget {
  const SearchNewAbo({super.key});

  @override
  SearchNewAboState createState() => SearchNewAboState();
}

class SearchNewAboState extends State<SearchNewAbo> {
  bool searching = true;
  List<Map<String, dynamic>> toShow = [];

  @override
  void initState() {
    super.initState();
    searchAbos();
  }

  Future<void> searchAbos() async {
    var inAbo =
        Provider.of<WalletProvider>(context, listen: false).aboList.map((e) {
      var u = e['url']!;
      var asUri = Uri.parse(u);
      return '${asUri.scheme.isNotEmpty ? asUri.scheme : 'https'}://${asUri.host}${asUri.path}';
    }).toList();

    var res = await get(Uri.parse(applicationEndpoint));
    List<Map<String, dynamic>> available = [];
    if (res.statusCode == 200) {
      List dec = jsonDecode(res.body);
      available = dec.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    toShow = [];

    if (available.isNotEmpty) {
      for (var entry in available) {
        var asUri = Uri.parse(entry['url']);
        var toCheck = '${asUri.scheme}://${asUri.host}${asUri.path}';
        if (!inAbo.contains(toCheck)) {
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
              : SizedBox.expand(
                  child: SingleChildScrollView(
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: List.generate(toShow.length, (index) {
                        var e = toShow[index];
                        return InkWell(
                          onTap: () {
                            navigateClassic(WebViewWindow(
                              initialUrl: e['url'],
                              title: e['name'],
                              iconUrl: e['mainbgimg'],
                            ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: ContextCredentialCard(
                                borderWidth: 1,
                                edgeRadius: 10,
                                cardTitle: '',
                                backgroundImage: e.containsKey('mainbgimg') &&
                                        e['mainbgimg']!.isNotEmpty
                                    ? CachedImage(imageUrl: e['mainbgimg']!)
                                    : null,
                                backgroundColor: Colors.green.shade300,
                                cardTitleColor:
                                    const Color.fromARGB(255, 255, 255, 255),
                                subjectName:
                                    e['name'] != null && e['name']!.isNotEmpty
                                        ? e['name']!
                                        : e['url'] != null
                                            ? e['url']!
                                            : '',
                                bottomLeftText: const SizedBox(
                                  width: 0,
                                ),
                                bottomRightText: const SizedBox(
                                  width: 0,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
    );
  }
}
