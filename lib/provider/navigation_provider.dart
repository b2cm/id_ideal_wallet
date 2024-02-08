import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';

class NavigationProvider extends ChangeNotifier {
  int activeIndex = 0;
  List<int> pageStack = [];
  String webViewUrl = 'https://hidy.app';
  VerifiableCredential? credential;
  bool canPop = true;

  void changePage(List<int> newIndex,
      {String? webViewUrl, VerifiableCredential? credential}) {
    if (newIndex.first != activeIndex) {
      canPop = false;
      activeIndex = newIndex.first;
      while (pageStack.isNotEmpty && newIndex.contains(pageStack.last)) {
        pageStack.removeLast();
      }
      pageStack.add(newIndex.first);
      if (webViewUrl != null) {
        this.webViewUrl = webViewUrl;
      }
      if (credential != null) {
        this.credential = credential;
      }
      notifyListeners();
    }
  }

  void goBack() {
    if (pageStack.isNotEmpty) {
      pageStack.removeLast();
    }
    if (pageStack.isEmpty) {
      if (activeIndex == 0) {
        Navigator.of(navigatorKey.currentContext!).pop();
      } else {
        canPop = true;
        activeIndex = 0;
      }
    } else {
      activeIndex = pageStack.last;
    }
    notifyListeners();
  }
}
