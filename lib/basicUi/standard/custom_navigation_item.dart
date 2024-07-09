import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/navigation_pages.dart';
import 'package:id_ideal_wallet/provider/navigation_provider.dart';

class CustomNavigationItem extends StatelessWidget {
  final String text;
  final IconData activeIcon, inactiveIcon;
  final List<NavigationPage> activeIndices;
  final NavigationProvider navigator;

  const CustomNavigationItem(
      {super.key,
      required this.text,
      required this.activeIcon,
      required this.inactiveIcon,
      required this.activeIndices,
      required this.navigator});

  @override
  Widget build(BuildContext context) {
    bool active = activeIndices.contains(navigator.activeIndex);
    return InkWell(
      onTap: () => navigator.changePage(activeIndices),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            shape: BoxShape.rectangle,
            color: active ? Colors.grey.shade400 : Colors.grey.shade100,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: Icon(active ? activeIcon : inactiveIcon),
          ),
        ),
        Text(text),
      ]),
    );
  }
}
