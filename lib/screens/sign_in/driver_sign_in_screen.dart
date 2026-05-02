// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

import '../driver_registration/driver_home_screen.dart';
import '../driver_registration/driver_registration_screen.dart';

class DriverSignInScreen extends StatefulWidget {
  static String routeName = "/driver_sign_in";

  const DriverSignInScreen({super.key});

  @override
  State<DriverSignInScreen> createState() => _DriverSignInScreenState();
}

class _DriverSignInScreenState extends State<DriverSignInScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> loginDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 🔥 Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // 🔥 Driver check
      final doc = await db.collection('drivers').doc(uid).get();

      final data = doc.data();
      if (!doc.exists || data?['role'] != 'driver') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          _error = "This account is not registered as a driver";
          _loading = false;
        });
        return;
      }

      final status = (data?['status'] as String? ?? '').trim().toLowerCase();
      final isBlocked = data?['isBlocked'] == true ||
          data?['blocked'] == true ||
          status == 'blocked' ||
          status == 'disabled';
      if (isBlocked) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        setState(() {
          _error = "This driver account has been blocked by the admin";
          _loading = false;
        });
        return;
      }

      // ✅ Navigate
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        DriverHomeScreen.routeName,
        (route) => false,
      );

    } on FirebaseAuthException {
      setState(() {
        _error = "Invalid email or password";
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = "Something went wrong";
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Sign In")),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    const Text(
                      "Welcome Driver",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Text(
                      "Sign in with your email and password",
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // EMAIL
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Required";
                        if (!value.contains("@")) return "Enter valid email";
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: "Email",
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Required";
                        if (value.length < 8) return "Min 8 characters";
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return "Add uppercase letter";
                        }
                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return "Add lowercase letter";
                        }
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return "Add number";
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: "Password",
                      ),
                    ),

                    const SizedBox(height: 8),

                    // FORGOT PASSWORD
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, "/forgot_password");
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ERROR
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 16),

                    // BUTTON
                    ElevatedButton(
                      onPressed: _loading ? null : loginDriver,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text("Continue"),
                    ),

                    const SizedBox(height: 20),

                    // ✅ ONLY THIS REGISTER TEXT
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          DriverRegistrationScreen.routeName,
                        );
                      },
                      child: const Text(
                        "No account? Register as Driver",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
