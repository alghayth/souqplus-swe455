import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:souqplus/components/app_bottom_nav.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/screens/sign_in/sign_in_screen.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  static String routeName = '/my_account';

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  static const Color _dangerRed = Color(0xFFB3261E);
  static final RegExp _nameRegExp = RegExp(
    r"^[A-Za-z\u0600-\u06FF][A-Za-z\u0600-\u06FF\s'-]*$",
  );
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final FirebaseFirestore _namedFirestore = db;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String? _validateFullName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Full name is required';
    }
    if (text.length > 20) {
      return 'Full name must be 20 characters or less';
    }
    if (!_nameRegExp.hasMatch(text)) {
      return 'Full name can only contain letters';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Phone number must contain digits only';
    }
    if (!text.startsWith('05')) {
      return 'Phone number must start with 05';
    }
    if (text.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        SignInScreen.routeName,
        (route) => false,
      );
      return;
    }

    try {
      final userDoc = await _namedFirestore.collection('users').doc(user.uid).get();

      final data = userDoc.data();
      _fullNameController.text =
          (data?['fullName'] as String?)?.trim().isNotEmpty == true
              ? (data!['fullName'] as String)
              : (user.displayName ?? '');
      _emailController.text =
          (data?['email'] as String?)?.trim().isNotEmpty == true
              ? (data!['email'] as String)
              : (user.email ?? '');
      _phoneController.text = (data?['phoneNumber'] as String?) ?? '';
      _addressController.text = (data?['address'] as String?) ?? '';
    } catch (_) {
      _fullNameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = '';
      _addressController.text = '';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final user = _currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final email = (user.email ?? _emailController.text).trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (fullName != (user.displayName ?? '')) {
        await user.updateDisplayName(fullName);
      }

      await _namedFirestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': email,
        'phoneNumber': phone,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'Please sign in again, then update your account.'
          : 'Update failed: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database update failed: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Delete this account permanently?'),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete Account'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
        actions: const [SizedBox.shrink()],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    String deleteStep = 'start';
    try {
      final uid = user.uid;
      deleteStep = 'loading your products';
      final products = await _namedFirestore
          .collection('products')
          .where('ownerUid', isEqualTo: uid)
          .get();

      deleteStep = 'deleting your products';
      for (final doc in products.docs) {
        await doc.reference.delete();
      }

      deleteStep = 'deleting your user profile';
      await _namedFirestore.collection('users').doc(uid).delete();

      deleteStep = 'deleting auth account';
      await user.delete();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        SignInScreen.routeName,
        (route) => false,
        arguments: 'Account deleted successfully.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'Please sign in again, then retry deleting your account.'
          : 'Delete failed at "$deleteStep": ${e.message ?? e.code}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed at "$deleteStep": ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const PageHeaderTitle('Edit Profile')),
      floatingActionButton: const AppNavFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z\u0600-\u06FF\s'-]"),
                        ),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: _validateFullName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true,
                      style: TextStyle(color: Colors.grey.shade700),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        helperText: 'Read-only: email cannot be changed here',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        suffixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        helperText: 'Enter 10 digits starting with 05',
                      ),
                      validator: _validatePhoneNumber,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      keyboardType: TextInputType.streetAddress,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'City is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isDeleting) ? null : _saveChanges,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit'),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dangerRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: (_isSaving || _isDeleting) ? null : _deleteAccount,
                        icon: const Icon(Icons.delete_outline),
                        label: _isDeleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Delete Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
