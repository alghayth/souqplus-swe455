import 'package:flutter/material.dart';

import '../../components/no_account_text.dart';
import 'components/sign_form.dart';

class SignInScreen extends StatefulWidget {
  static String routeName = "/sign_in";

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _didShowRouteMessage = false;

  @override
  Widget build(BuildContext context) {
    if (!_didShowRouteMessage) {
      final routeMessage = ModalRoute.of(context)?.settings.arguments;
      if (routeMessage is String && routeMessage.isNotEmpty) {
        _didShowRouteMessage = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(routeMessage)));
        });
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Sign In")),
      body: const SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 16),
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Sign in with your email and password",
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  SignForm(showAdminLoginLink: true),
                  SizedBox(height: 20),
                  NoAccountText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
