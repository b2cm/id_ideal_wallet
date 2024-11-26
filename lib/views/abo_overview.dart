import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:id_ideal_wallet/basicUi/standard/cached_image.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:provider/provider.dart';

class AboOverview extends StatefulWidget {
  const AboOverview({super.key});

  @override
  AboOverviewState createState() => AboOverviewState();
}

class AboOverviewState extends State<AboOverview>
    with TickerProviderStateMixin {
  Offset tapPosition = const Offset(0, 0);
  List<AnimationController> controllers = [];
  List<Animation<Offset>> animations = [];
  List<GlobalKey> cardKeys = [];
  bool deleteSelected = false;

  @override
  void initState() {
    super.initState();
    var wallet = Provider.of<WalletProvider>(context, listen: false);
    for (int i = 0; i < wallet.aboList.length + 3; i++) {
      var controller = AnimationController(
        duration: const Duration(milliseconds: 250),
        vsync: this,
      );
      late final Animation<Offset> offsetAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, -0.05),
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.linear,
      ));
      controllers.add(controller);
      animations.add(offsetAnimation);
      cardKeys.add(GlobalKey());
    }
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Consumer<WalletProvider>(builder: (context, wallet, child) {
              return wallet.aboList.isNotEmpty
                  ? SizedBox.expand(
                      child: SingleChildScrollView(
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisSpacing: 15,
                          crossAxisCount: 3,
                          children:
                              List.generate(wallet.aboList.length + 1, (index) {
                            if (index == 0) {
                              return InkWell(
                                onTap: () {
                                  Provider.of<NavigationProvider>(context,
                                          listen: false)
                                      .changePage(
                                          [NavigationPage.searchNewAbo]);
                                },
                                child: Column(children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.2,
                                    height:
                                        MediaQuery.of(context).size.width * 0.2,
                                    decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(
                                      Icons.add,
                                      size: 45,
                                    ),
                                  ),
                                  Text(AppLocalizations.of(context)!.add)
                                ]),
                              );
                            }
                            var e = wallet.aboList[index - 1];
                            return GestureDetector(
                              onTapDown: (details) {
                                tapPosition = details.globalPosition;
                              },
                              onLongPress: () {
                                controllers[index - 1].forward();
                                controllers[index - 1].repeat(reverse: true);

                                final RenderBox overlay = Overlay.of(context)
                                    .context
                                    .findRenderObject() as RenderBox;

                                final RenderBox card = cardKeys[index - 1]
                                    .currentContext!
                                    .findRenderObject() as RenderBox;

                                final RelativeRect position =
                                    RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    card.localToGlobal(
                                      const Offset(0, -50),
                                    ),
                                    card.localToGlobal(
                                      card.size.topLeft(Offset.zero) +
                                          const Offset(55, 0),
                                    ),
                                  ),
                                  Offset.zero & overlay.size,
                                );

                                showMenu(
                                  color: Colors.white,
                                  surfaceTintColor: Colors.white,
                                  context: context,
                                  position: position,
                                  constraints: const BoxConstraints(
                                      minWidth: 30, minHeight: 30),
                                  items: [
                                    CustomPopupMenuItem(
                                      onTap: () {
                                        deleteSelected = true;
                                      },
                                      color: Colors.white,
                                      child: const SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: Icon(
                                          Icons.delete,
                                        ),
                                      ),
                                    )
                                  ],
                                ).then((value) async {
                                  if (deleteSelected) {
                                    await showDialog(
                                      context: navigatorKey.currentContext!,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .delete),
                                        content: Card(
                                            child: Text(
                                                AppLocalizations.of(context)!
                                                    .deletionNoteApp)),
                                        actions: [
                                          TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(
                                                  AppLocalizations.of(context)!
                                                      .cancel)),
                                          TextButton(
                                              onPressed: () async {
                                                wallet.deleteAbo(index - 1);
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(
                                                  AppLocalizations.of(context)!
                                                      .delete))
                                        ],
                                      ),
                                    );
                                  }
                                  controllers[index - 1].reset();
                                  deleteSelected = false;
                                });
                              },
                              onTap: () {
                                navigateClassic(WebViewWindow(
                                  initialUrl: e.url.replaceAll(
                                      'wid=', 'wid=${wallet.lndwId}'),
                                  title: e.name,
                                  iconUrl: e.pictureUrl,
                                ));
                              },
                              child: SlideTransition(
                                position: animations[index - 1],
                                child: Column(children: [
                                  SizedBox(
                                    key: cardKeys[index - 1],
                                    width:
                                        MediaQuery.of(context).size.width * 0.2,
                                    height:
                                        MediaQuery.of(context).size.width * 0.2,
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
                                  Text(
                                    e.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 20),
                      child: InkWell(
                        onTap: () {
                          Provider.of<NavigationProvider>(context,
                                  listen: false)
                              .changePage([NavigationPage.searchNewAbo]);
                        },
                        child: Column(children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.2,
                            height: MediaQuery.of(context).size.width * 0.2,
                            decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(
                              Icons.add,
                              size: 45,
                            ),
                          ),
                          Text(AppLocalizations.of(context)!.add)
                        ]),
                      ),
                    );
            }),
          ),
        ));
  }
}

class CustomPopupMenuItem<T> extends PopupMenuItem<T> {
  final Color color;

  const CustomPopupMenuItem({
    super.key,
    super.value,
    super.enabled,
    super.child,
    super.onTap,
    required this.color,
  });

  @override
  CustomPopupMenuItemState<T> createState() => CustomPopupMenuItemState<T>();
}

class CustomPopupMenuItemState<T>
    extends PopupMenuItemState<T, CustomPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      color: widget.color,
      child: super.build(context),
    );
  }
}
