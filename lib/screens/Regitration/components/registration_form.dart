import 'package:flutter/material.dart';
import 'package:souqplus/screens/init_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:souqplus/services/push_token_service.dart';

import '../../../components/custom_suffix_icon.dart';
import '../../../constants.dart';

class RegistrationForm extends StatefulWidget {
  const RegistrationForm({super.key});

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  static final RegExp _nameRegExp = RegExp(
    r"^[A-Za-z\u0600-\u06FF][A-Za-z\u0600-\u06FF\s'-]*$",
  );
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? password;
  String passwordInput = '';
  bool _loading = false;

  bool get hasMinLength => passwordInput.length >= 8;
  bool get hasLetter => RegExp(r'[A-Za-z]').hasMatch(passwordInput);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(passwordInput);
  bool get isPasswordValid => hasMinLength && hasLetter && hasNumber;

  String? _validateName(String? value, String fieldLabel) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$fieldLabel is required';
    }
    if (text.length < 2) {
      return '$fieldLabel must be at least 2 characters';
    }
    if (text.length > 30) {
      return '$fieldLabel cannot exceed 30 characters';
    }
    if (!_nameRegExp.hasMatch(text)) {
      return '$fieldLabel can only contain letters';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Phone number must contain digits only';
    }
    if (!phone.startsWith('05')) {
      return 'Phone number must start with 05';
    }
    if (phone.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  Future<void> _saveUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String address,
  }) async {
    final data = {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'role': 'user',
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'otpPending': false,
    };

    final namedFirestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'souqplus',
    );

    try {
      await namedFirestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      return;
    } on FirebaseException {
      // Fallback to default DB.
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _createAccountFallback({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String address,
    required String password,
  }) async {
    final fullName = '$firstName $lastName';
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final createdUser = credential.user;
    if (createdUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'Could not create account.',
      );
    }
    await createdUser.updateDisplayName(fullName);
    await _saveUserProfile(
      uid: createdUser.uid,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      address: address,
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields.')),
      );
      return;
    }

    final trimmedFirstName = _firstNameController.text.trim();
    final trimmedLastName = _lastNameController.text.trim();
    final trimmedEmail = _emailController.text.trim().toLowerCase();
    final trimmedPhoneNumber = _phoneController.text.trim();
    final trimmedAddress = _addressController.text.trim();
    final trimmedPassword = _passwordController.text.trim();

    setState(() => _loading = true);
    try {
      await _createAccountFallback(
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        email: trimmedEmail,
        phoneNumber: trimmedPhoneNumber,
        address: trimmedAddress,
        password: trimmedPassword,
      );
      await PushTokenService.saveUserFcmToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        InitScreen.routeName,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'email-already-in-use'
          ? 'This email is already registered. Please sign in.'
          : (e.message ?? 'Failed to create account.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.message ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _firstNameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r"[A-Za-z\u0600-\u06FF\s'-]"),
              ),
            ],
            validator: (value) => _validateName(value, 'First name'),
            decoration: const InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/person.svg'),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _lastNameController,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r"[A-Za-z\u0600-\u06FF\s'-]"),
              ),
            ],
            validator: (value) => _validateName(value, 'Last name'),
            decoration: const InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/person.svg'),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              } else if (!emailValidatorRegExp.hasMatch(value.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/Mail.svg'),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            maxLength: 10,
            validator: _validatePhoneNumber,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '05XXXXXXXX',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(
                svgIcon: 'assets/icons/phone-number.svg',
              ),
              counterText: '',
              helperText: 'Enter 10 digits starting with 05',
              helperStyle: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (value) {
              setState(() {
                passwordInput = value;
                password = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              } else if (!isPasswordValid) {
                return 'Password does not meet requirements';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/Lock.svg'),
            ),
          ),
          if (passwordInput.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildPasswordRule('At least 8 characters', hasMinLength),
            _buildPasswordRule('Contains a letter', hasLetter),
            _buildPasswordRule('Contains a number', hasNumber),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              } else if (password != value) {
                return 'Passwords do not match';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter your password',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/Lock.svg'),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _addressController,
            keyboardType: TextInputType.streetAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'City is required';
              } else if (value.trim().length < 3) {
                return 'City is too short';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'City',
              hintText: 'Enter your city',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(
                svgIcon: 'assets/icons/Location.svg',
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _loading ? null : _submitRegistration,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRule(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          color: isValid
              ? Colors.green
              : const Color.fromARGB(255, 153, 42, 34),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isValid
                ? Colors.green
                : const Color.fromARGB(255, 153, 42, 34),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
