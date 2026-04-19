import 'package:flutter/material.dart';

import '../Regitration/registration_screen.dart';
import '../driver_registration/driver_registration_screen.dart';
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
                  _RegistrationButtons(),
                  SizedBox(height: 16),
                  SignForm(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationButtons extends StatelessWidget {
  const _RegistrationButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () =>
                Navigator.pushNamed(context, RegistrationScreen.routeName),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 20),
                SizedBox(width: 8),
                Flexible(child: Text('Register as User')),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              DriverRegistrationScreen.routeName,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining_rounded, size: 20),
                SizedBox(width: 8),
                Flexible(child: Text('Register as Driver')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
