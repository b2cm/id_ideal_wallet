import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

class AboOverview extends StatefulWidget {
  const AboOverview({super.key});

  @override
  AboOverviewState createState() => AboOverviewState();
}

class AboOverviewState extends State<AboOverview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Consumer<WalletProvider>(builder: (context, wallet, child) {
            return wallet.aboList.isNotEmpty
                ? SizedBox.expand(
                    child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    children: wallet.aboList
                        .map((e) => InkWell(
                              onTap: () {
                                Provider.of<NavigationProvider>(context,
                                        listen: false)
                                    .changePage([5],
                                        webViewUrl: e['url']
                                            .toString()
                                            .replaceAll('wid=',
                                                'wid=${wallet.lndwId}'));
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  child: ContextCredentialCard(
                                    borderWidth: 1,
                                    edgeRadius: 10,
                                    cardTitle: '',
                                    backgroundImage: e
                                                .containsKey('mainbgimage') &&
                                            e['mainbgimage']!.isNotEmpty
                                        ? Image.network(e['mainbgimage']!).image
                                        : null,
                                    backgroundColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    cardTitleColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    subjectName: e['name'] ?? '',
                                    bottomLeftText: const SizedBox(
                                      width: 0,
                                    ),
                                    bottomRightText: const SizedBox(
                                      width: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ))
                : const Center(
                    child:
                        Text('Sie haben noch keine Anwendungen hinzugefügt'));
          }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Provider.of<NavigationProvider>(context, listen: false)
              .changePage([9]);
        },
        label: Text(AppLocalizations.of(context)!.add),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
