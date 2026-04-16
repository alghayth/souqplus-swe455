// ignore_for_file: file_names

import 'package:flutter/material.dart';
import '../../constants.dart';
import '../sign_in/sign_in_screen.dart';
import '../sign_in/driver_sign_in_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  static String routeName = "/role_selection";

  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          "assets/images/logo.png",
          height: 40,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Continue as", style: headingStyle),
              const SizedBox(height: 40),

              // ✅ USER
              RoleCard(
                title: "User",
                icon: Icons.person,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    SignInScreen.routeName,
                  );
                },
              ),

              const SizedBox(height: 20),

              // ✅ DRIVER
              RoleCard(
                title: "Driver",
                icon: Icons.delivery_dining,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    DriverSignInScreen.routeName,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: kPrimaryColor),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}