import 'package:flutter/material.dart';

const terminalGreen = Color(0xFF00FF41);
const terminalBackground = Color(0xFF0A0E0A);
const terminalDarkGreen = Color(0xFF00AA2B);
const scanlineColor = Color(0x0A00FF41);

ThemeData appTheme() => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: terminalBackground,
  appBarTheme: AppBarTheme(
    backgroundColor: terminalBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'JetBrains',
      fontSize: 16,
      color: terminalGreen,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
    iconTheme: IconThemeData(color: terminalGreen),
  ),
);