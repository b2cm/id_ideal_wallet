import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/id_card.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:provider/provider.dart';

class AboOverview extends StatefulWidget {
  const AboOverview({super.key});

  @override
  AboOverviewState createState() => AboOverviewState();
}

class AboOverviewState extends State<AboOverview> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Text('Abonements',
            style: Theme.of(context).primaryTextTheme.headlineLarge),
        Consumer<WalletProvider>(builder: (context, wallet, child) {
          return ListView.builder(
              shrinkWrap: true,
              itemCount: wallet.aboGroups.length,
              itemBuilder: (context, index) {
                var groupName = wallet.aboGroups.keys.toList()[index];
                List<Widget> c = wallet.aboGroups[groupName]!.map((e) {
                  var data = wallet.getAboData(e);

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => WebViewWindow(
                              initialUrl: data['url']
                                  .toString()
                                  .replaceAll('wid=', 'wid=${wallet.lndwId}'),
                              title:
                                  data['webViewTitle'] ?? data['name'] ?? '')));
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.4,
                            child: ContextCredentialCard(
                                borderWidth: 1,
                                edgeRadius: 10,
                                cardTitle: '',
                                backgroundColor: data['bgcolor'] != null
                                    ? HexColor.fromHex(data['bgcolor'])
                                    : const Color.fromARGB(255, 255, 255, 255),
                                cardTitleColor: data['textcolor'] != null
                                    ? HexColor.fromHex(data['textcolor'])
                                    : const Color.fromARGB(255, 255, 255, 255),
                                subjectName: data['name'],
                                bottomLeftText: const SizedBox(
                                  width: 0,
                                ),
                                bottomRightText: const SizedBox(
                                  width: 0,
                                )))),
                  );
                }).toList();
                return ExpansionTile(
                  shape: const Border(),
                  title: Text(groupName),
                  children: [
                    Wrap(
                      children: c,
                    )
                  ],
                );
              });
        }),
      ]),
    );
  }
}
