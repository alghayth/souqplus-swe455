// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRegistrationScreen extends StatefulWidget {
  static String routeName = "/driver_register";

  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final plateController = TextEditingController();
  final modelController = TextEditingController();
  final brandController = TextEditingController();
  final passwordController = TextEditingController();

  bool _loading = false;

  // 🔥 Password rules
  bool hasUppercase(String value) => value.contains(RegExp(r'[A-Z]'));
  bool hasLowercase(String value) => value.contains(RegExp(r'[a-z]'));
  bool hasNumber(String value) => value.contains(RegExp(r'[0-9]'));

  Future<void> registerDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 🔥 Firebase Auth
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      // 🔥 Firestore
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'email': emailController.text.trim(),
        'fullName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'carPlate': plateController.text.trim(),
        'carModel': modelController.text.trim(),
        'carBrand': brandController.text.trim(),
        'role': 'driver',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver registered successfully")),
      );

      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed")),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Widget buildField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLength: maxLength,
        inputFormatters: maxLength != null
            ? [LengthLimitingTextInputFormatter(maxLength)]
            : null,
        validator: (value) {
          if (value == null || value.isEmpty) return "Required";

          if (label == "Email" && !value.contains("@")) {
            return "Enter valid email";
          }

          if (isPassword) {
            if (value.length < 8) return "Min 8 characters";
            if (!hasUppercase(value)) return "Add uppercase letter";
            if (!hasLowercase(value)) return "Add lowercase letter";
            if (!hasNumber(value)) return "Add number";
          }

          return null;
        },
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText:
              label == "Full Name" ? "Maximum 30 characters" : null,
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
      appBar: AppBar(title: const Text("Driver Registration")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // EMAIL
              buildField(emailController, "Email"),

              // FULL NAME
              buildField(nameController, "Full Name", maxLength: 30),

              // ✅ PHONE (UPDATED)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Required";

                    if (value.length != 10) {
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
                    border: OutlineInputBorder(),
                    counterText: "",
                  ),
                ),
              ),

              buildField(plateController, "Car Plate"),
              buildField(modelController, "Car Model"),
              buildField(brandController, "Car Brand"),

              // PASSWORD
              buildField(passwordController, "Password", isPassword: true),

              passwordRules(password),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : registerDriver,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}