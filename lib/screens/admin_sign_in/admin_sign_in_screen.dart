import 'package:flutter/material.dart';
import 'package:souqplus/screens/admin_dashboard/admin_dashboard_screen.dart';

import '../sign_in/components/sign_form.dart';
import '../sign_in/sign_in_screen.dart';

class AdminSignInScreen extends StatelessWidget {
  static String routeName = "/admin_sign_in";

  const AdminSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Login")),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Admin Access",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Sign in with your admin email and password",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const SignForm(
                    isAdminLogin: true,
                    successRouteName: AdminDashboardScreen.routeName,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(
                      context,
                      SignInScreen.routeName,
                    ),
                    child: const Text(
                      "Back to user sign in",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
