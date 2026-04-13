import 'package:flutter/material.dart';

import 'constants.dart';

class AppTheme {
  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: const Color.fromARGB(255, 253, 246, 210),
      fontFamily: "Muli",
      appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 27, 58, 104),
          elevation: 0,
          iconTheme: IconThemeData(color:kPrimaryColor),
          titleTextStyle: TextStyle(color: Color.fromARGB(255, 27, 58, 104))),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: kPrimaryColor),
        bodyMedium: TextStyle(color: kPrimaryColor),
        bodySmall: TextStyle(color: kTextColor),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: EdgeInsets.symmetric(horizontal: 42, vertical: 20),
        enabledBorder: outlineInputBorder,
        focusedBorder: outlineInputBorder,
        border: outlineInputBorder,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF1B3A68),
          foregroundColor: kPrimaryColor,
          minimumSize: const Size(double.infinity, 48),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}

const OutlineInputBorder outlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(28)),
  borderSide: BorderSide(color:  Color.fromARGB(255, 27, 58, 104)),
  gapPadding: 10,
);
