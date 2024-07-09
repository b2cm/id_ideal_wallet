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
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Consumer<WalletProvider>(builder: (context, wallet, child) {
              return wallet.aboList.isNotEmpty
                  ? SizedBox.expand(
                      child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: List.generate(wallet.aboList.length, (index) {
                        var e = wallet.aboList[index];
                        return GestureDetector(
                          onTapDown: (details) {
                            tapPosition = details.globalPosition;
                          },
                          onLongPress: () {
                            controllers[index].forward();
                            controllers[index].repeat(reverse: true);

                            final RenderBox overlay = Overlay.of(context)
                                .context
                                .findRenderObject() as RenderBox;

                            final RenderBox card = cardKeys[index]
                                .currentContext!
                                .findRenderObject() as RenderBox;

                            final RelativeRect position = RelativeRect.fromRect(
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
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                        AppLocalizations.of(context)!.delete),
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
                                            wallet.deleteAbo(index);
                                            Navigator.of(context).pop();
                                          },
                                          child: Text(
                                              AppLocalizations.of(context)!
                                                  .delete))
                                    ],
                                  ),
                                );
                              }
                              controllers[index].reset();
                              deleteSelected = false;
                            });
                          },
                          onTap: () {
                            Provider.of<NavigationProvider>(context,
                                    listen: false)
                                .changePage([5],
                                    webViewUrl: e['url'].toString().replaceAll(
                                        'wid=', 'wid=${wallet.lndwId}'));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: SlideTransition(
                                position: animations[index],
                                child: ContextCredentialCard(
                                  key: cardKeys[index],
                                  borderWidth: 1,
                                  edgeRadius: 10,
                                  cardTitle: '',
                                  backgroundImage: e
                                              .containsKey('mainbgimage') &&
                                          e['mainbgimage']!.isNotEmpty
                                      ? Image.network(e['mainbgimage']!).image
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
                          ),
                        );
                      }).toList(),
                    ))
                  : Center(
                      child: Text(AppLocalizations.of(context)!.noAppNote));
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
