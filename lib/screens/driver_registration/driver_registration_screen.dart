// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/screens/driver_registration/driver_home_screen.dart';

import '../../constants.dart';

class DriverRegistrationScreen extends StatefulWidget {
  static String routeName = "/driver_register";

  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  static const int emailMaxLength = 30;
  static const int nameMaxLength = 30;
  static const int phoneMaxLength = 10;
  static const int plateMaxLength = 10;
  static const int carTextMaxLength = 20;
  static const int passwordMaxLength = 20;

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final plateController = TextEditingController();
  final modelController = TextEditingController();
  final brandController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _loading = false;

  // 🔥 Password rules
  bool hasUppercase(String value) => value.contains(RegExp(r'[A-Z]'));
  bool hasLowercase(String value) => value.contains(RegExp(r'[a-z]'));
  bool hasNumber(String value) => value.contains(RegExp(r'[0-9]'));

  static const TextStyle _helperStyle = TextStyle(
    color: Colors.grey,
    fontSize: 12,
  );

  Future<void> registerDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = emailController.text.trim().toLowerCase();
      // 🔥 Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: passwordController.text.trim(),
          );

      String uid = userCredential.user!.uid;

      // 🔥 Firestore
      await db.collection('drivers').doc(uid).set({
        'uid': uid,
        'email': email,
        'fullName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'carPlate': plateController.text.trim(),
        'carModel': modelController.text.trim(),
        'carBrand': brandController.text.trim(),
        'role': 'driver',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver registered successfully")),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        DriverHomeScreen.routeName,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'email-already-in-use'
          ? 'This email is already registered. Please sign in.'
          : e.message ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save driver profile: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Registration failed")));
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    phoneController.dispose();
    plateController.dispose();
    modelController.dispose();
    brandController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    String? helperText,
    FormFieldValidator<String>? customValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ...?inputFormatters,
        ],
        validator: (value) {
          final customError = customValidator?.call(value);
          if (customError != null) return customError;

          final text = value?.trim() ?? "";
          if (text.isEmpty) return "$label is required";

          if (label == "Email" &&
              !RegExp(
                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
              ).hasMatch(text)) {
            return "Enter valid email";
          }

          if (label == "Full Name" && text.length < 2) {
            return "Full name must be at least 2 characters";
          }

          if (label == "Car Plate" && text.length < 3) {
            return "Car plate must be at least 3 characters";
          }

          if (isPassword) {
            if (text.length < 8) return "Min 8 characters";
            if (!hasUppercase(text)) return "Add uppercase letter";
            if (!hasLowercase(text)) return "Add lowercase letter";
            if (!hasNumber(text)) return "Add number";
          }

          return null;
        },
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          helperText: helperText,
          helperStyle: _helperStyle,
          counterText: "",
        ),
      ),
    );
  }

  Widget passwordRules(String password) {
    if (password.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rule("At least 8 characters", password.length >= 8),
        rule("Contains uppercase", hasUppercase(password)),
        rule("Contains lowercase", hasLowercase(password)),
        rule("Contains number", hasNumber(password)),
      ],
    );
  }

  Widget rule(String text, bool valid) {
    return Row(
      children: [
        Icon(
          valid ? Icons.check_circle : Icons.cancel,
          color: valid ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final password = passwordController.text;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset("assets/images/logo.png", height: 40),
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "Driver Registration",
                    style: headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    "Complete your driver details",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // EMAIL
                  buildField(
                    emailController,
                    "Email",
                    maxLength: emailMaxLength,
                    keyboardType: TextInputType.emailAddress,
                    helperText: "Enter the driver email address",
                  ),

                  // FULL NAME
                  buildField(
                    nameController,
                    "Full Name",
                    maxLength: nameMaxLength,
                    keyboardType: TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[A-Za-z\u0600-\u06FF\s'-]"),
                      ),
                    ],
                    helperText: "Maximum 30 characters",
                  ),

                  // ✅ PHONE (UPDATED)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: phoneMaxLength,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(phoneMaxLength),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Required";

                        if (value.length != phoneMaxLength) {
                          return "Phone must be 10 digits";
                        }

                        if (!value.startsWith("05")) {
                          return "Must start with 05";
                        }

                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        hintText: "05XXXXXXXX",
                        helperText: "Format: 05XXXXXXXX",
                        helperStyle: _helperStyle,
                        border: OutlineInputBorder(),
                        counterText: "",
                      ),
                    ),
                  ),

                  buildField(
                    plateController,
                    "Car Plate",
                    maxLength: plateMaxLength,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 -]'),
                      ),
                    ],
                    helperText: "Maximum 10 characters",
                  ),
                  buildField(
                    modelController,
                    "Car Model",
                    maxLength: carTextMaxLength,
                    helperText: "Maximum 20 characters",
                  ),
                  buildField(
                    brandController,
                    "Car Brand",
                    maxLength: carTextMaxLength,
                    helperText: "Maximum 20 characters",
                  ),

                  // PASSWORD
                  buildField(
                    passwordController,
                    "Password",
                    isPassword: true,
                    maxLength: passwordMaxLength,
                    helperText:
                        "8-20 chars with uppercase, lowercase, and number",
                  ),

                  buildField(
                    confirmPasswordController,
                    "Confirm Password",
                    isPassword: true,
                    maxLength: passwordMaxLength,
                    helperText: "Re-enter your password",
                    customValidator: (value) {
                      final text = value?.trim() ?? "";
                      if (text.isEmpty) return "Confirm Password is required";
                      if (text != passwordController.text.trim()) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),

                  passwordRules(password),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _loading ? null : registerDriver,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text("Register"),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'By continuing your confirm that you agree \nwith our Term and Condition',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 12,
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
