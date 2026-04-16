// ignore_for_file: file_names

import 'package:flutter/material.dart';

class DriverHomeScreen extends StatelessWidget {
  // ✅ REQUIRED — fixes your red error
  static String routeName = "/driver_home";

  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Home"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Welcome Driver 🚗",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}