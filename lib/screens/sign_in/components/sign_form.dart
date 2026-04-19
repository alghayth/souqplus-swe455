import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:souqplus/screens/admin_dashboard/admin_dashboard_screen.dart';
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
      final adminAccess = await _adminAccessService.checkCurrentUserAdmin();
      await PushTokenService.saveUserFcmToken();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful')));

      Navigator.pushNamedAndRemoveUntil(
        context,
        adminAccess.isAdmin
            ? AdminDashboardScreen.routeName
            : InitScreen.routeName,
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
    final password = _passwordController.text;

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
              helperText: '8-20 chars with uppercase, lowercase, and number',
            ),
          ),
          if (password.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPasswordRule('At least 8 characters', password.length >= 8),
            _buildPasswordRule(
              'No more than 20 characters',
              password.length <= AuthFormValidator.passwordMaxLength,
            ),
            _buildPasswordRule(
              'Contains an uppercase letter',
              AuthFormValidator.hasUppercase(password),
            ),
            _buildPasswordRule(
              'Contains a lowercase letter',
              AuthFormValidator.hasLowercase(password),
            ),
            _buildPasswordRule(
              'Contains a number',
              AuthFormValidator.hasNumber(password),
            ),
          ],
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

  Widget _buildPasswordRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid
                ? Colors.green
                : const Color.fromARGB(255, 153, 42, 34),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isValid
                    ? Colors.green
                    : const Color.fromARGB(255, 153, 42, 34),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
