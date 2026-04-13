import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants.dart';
import 'components/otp_form.dart';

class OtpScreen extends StatefulWidget {
  static String routeName = '/otp';

  final String email;
  final Map<String, dynamic>? registrationData;
  final String? initialError;

  const OtpScreen({
    super.key,
    required this.email,
    this.registrationData,
    this.initialError,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsUntilResend = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    if (widget.initialError != null && widget.initialError!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.initialError!)),
        );
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsUntilResend = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend -= 1);
    });
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final namedFirestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'souqplus',
    );

    try {
      await namedFirestore.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
      return;
    } on FirebaseException {
      // Fallback to default Firestore DB when named DB write fails.
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<bool> _completeRegistrationIfNeeded() async {
    final data = widget.registrationData;
    if (data == null) return true;

    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    final phoneNumber = (data['phoneNumber'] as String? ?? '').trim();
    final address = (data['address'] as String? ?? '').trim();
    final password = (data['password'] as String? ?? '').trim();
    final email = widget.email.trim();

    if (email.isEmpty || firstName.isEmpty || lastName.isEmpty || password.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration data is incomplete. Please sign up again.')),
      );
      return false;
    }

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create account. Please try again.')),
        );
        return false;
      }

      final fullName = '$firstName $lastName';
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
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      final message = e.code == 'email-already-in-use'
          ? 'This email is already registered. Please sign in.'
          : (e.message ?? 'Failed to create account.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } on FirebaseException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: ${e.message ?? e.code}')),
      );
      return false;
    }
  }

  Future<void> _verifyOtp(String code) async {
    final supabase = Supabase.instance.client;
    final normalizedEmail = widget.email.trim().toLowerCase();
    setState(() => _isVerifying = true);
    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: normalizedEmail,
        token: code.trim(),
      );

      if (!mounted) return;
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Please check your email code.')),
        );
        return;
      }

      final registrationDone = await _completeRegistrationIfNeeded();
      if (!mounted || !registrationDone) return;

      Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP verification failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsUntilResend > 0) return;

    final supabase = Supabase.instance.client;
    final normalizedEmail = widget.email.trim().toLowerCase();
    setState(() => _isResending = true);
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithOtp(
        email: normalizedEmail,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP resent to $normalizedEmail')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final isRateLimited = e is AuthApiException &&
          (e.code == 'over_email_send_rate_limit' || e.statusCode == '429');
      final message = isRateLimited
          ? 'Too many OTP requests. Please wait a few minutes before retrying.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend OTP.')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          height: 40,
        ),
      ),
      body: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'OTP Verification',
                  style: headingStyle,
                ),
                const Text('We sent your code to'),
                Text(
                  widget.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('This code will expire in '),
                    TweenAnimationBuilder(
                      tween: Tween(begin: 30.0, end: 0.0),
                      duration: const Duration(seconds: 30),
                      builder: (_, dynamic value, child) => Text(
                        '00:${value.toInt()}',
                        style: const TextStyle(color: kPrimaryColor),
                      ),
                    ),
                  ],
                ),
                OtpForm(
                  onSubmit: _verifyOtp,
                  isLoading: _isVerifying,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: (_isResending || _secondsUntilResend > 0) ? null : _resendOtp,
                  child: Text(
                    _isResending
                        ? 'Resending...'
                        : _secondsUntilResend > 0
                            ? 'Resend in ${_secondsUntilResend}s'
                            : 'Resend OTP Code',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
