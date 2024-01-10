import 'package:flutter/material.dart';

class IdWalletDesignTheme {
  final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      fontFamily: 'Outfit',
      primaryTextTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      primaryColor: Colors.white,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      expansionTileTheme: const ExpansionTileThemeData(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0));
}
