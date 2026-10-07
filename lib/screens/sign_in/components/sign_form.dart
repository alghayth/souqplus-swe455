import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:souqplus/screens/admin_dashboard/admin_dashboard_screen.dart';
import 'package:souqplus/screens/driver_registration/driver_home_screen.dart';
import 'package:souqplus/screens/init_screen.dart';
import 'package:souqplus/services/admin_access_service.dart';
import 'package:souqplus/services/auth_form_validator.dart';
import 'package:souqplus/services/auth_login_service.dart';
import 'package:souqplus/services/push_token_service.dart';

import '../../../components/custom_suffix_icon.dart';
import '../../../helper/keyboard.dart';
import '../../forgot_password/forgot_password_screen.dart';

class SignForm extends StatefulWidget {
  const SignForm({super.key});

  @override
  State<SignForm> createState() => _SignFormState();
}

class _SignFormState extends State<SignForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authLoginService = const AuthLoginService();
  final _adminAccessService = const AdminAccessService();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _formMessage;

  void _clearMessage() {
    if (_formMessage == null) return;
    setState(() => _formMessage = null);
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final requiredFieldsMessage = AuthFormValidator.validateRequiredFields(
      email: email,
      password: password,
    );

    if (requiredFieldsMessage != null) {
      setState(() => _formMessage = requiredFieldsMessage);
      _formKey.currentState?.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    KeyboardUtil.hideKeyboard(context);
    setState(() => _loading = true);

    try {
      await _authLoginService.signIn(email: email, password: password);
      final isBlocked = await _authLoginService.isCurrentUserBlocked();
      if (isBlocked) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(
          () => _formMessage =
              'This account has been blocked by the admin. Please contact support.',
        );
        return;
      }

      final adminAccess = await _adminAccessService.checkCurrentUserAdmin();
      final isDriver = adminAccess.isAdmin
          ? false
          : await _authLoginService.isCurrentUserDriver();
      if (isDriver && await _authLoginService.isCurrentDriverBlocked()) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(
          () => _formMessage =
              'This driver account has been blocked by the admin.',
        );
        return;
      }
      await PushTokenService.saveUserFcmToken(
        collectionPath: isDriver ? 'drivers' : 'users',
      );
      if (!mounted) return;

      final String destinationRoute;
      if (adminAccess.isAdmin) {
        destinationRoute = AdminDashboardScreen.routeName;
      } else if (isDriver) {
        destinationRoute = DriverHomeScreen.routeName;
      } else {
        destinationRoute = InitScreen.routeName;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful')));

      Navigator.pushNamedAndRemoveUntil(
        context,
        destinationRoute,
        (route) => false,
      );
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      setState(() => _formMessage = _authLoginService.mapAuthError(exception));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _formMessage = 'Unable to sign in right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: AuthFormValidator.emailMaxLength,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                AuthFormValidator.emailMaxLength,
              ),
            ],
            onChanged: (_) => _clearMessage(),
            validator: (value) => AuthFormValidator.validateEmail(value ?? ''),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: CustomSuffixIcon(svgIcon: 'assets/icons/Mail.svg'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            maxLength: AuthFormValidator.passwordMaxLength,
            inputFormatters: [
              LengthLimitingTextInputFormatter(
                AuthFormValidator.passwordMaxLength,
              ),
            ],
            onChanged: (_) {
              setState(() {});
              _clearMessage();
            },
            validator: (value) =>
                AuthFormValidator.validatePassword(value ?? ''),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                tooltip: _obscurePassword ? 'Show Password' : 'Hide Password',
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  ForgotPasswordScreen.routeName,
                ),
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
          if (_formMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _formMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submitLogin,
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
}
