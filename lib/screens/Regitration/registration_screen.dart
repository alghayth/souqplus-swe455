// ignore_for_file: file_names

import 'package:flutter/material.dart';

import '../../constants.dart';
import 'components/registration_form.dart';

class RegistrationScreen extends StatelessWidget {
  static String routeName = "/registration";

  const RegistrationScreen({super.key});
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
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text("Register Account", style: headingStyle),
                  const Text(
                    "Complete your details",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const RegistrationForm(),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  Text(
                    'By continuing your confirm that you agree \nwith our Term and Condition',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

