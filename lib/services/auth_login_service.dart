import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

class AuthLoginService {
  const AuthLoginService();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    // Firebase Authentication handles password storage securely on the backend.
    // The app never stores plain-text passwords locally.
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  Future<bool> isCurrentUserBlocked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await db.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data == null) return false;

    final status = (data['status'] as String? ?? '').trim().toLowerCase();
    return data['isBlocked'] == true ||
        data['blocked'] == true ||
        status == 'blocked' ||
        status == 'disabled';
  }

  Future<bool> isCurrentUserDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final driverDoc = await db.collection('drivers').doc(user.uid).get();
    final data = driverDoc.data();
    if (data == null) return false;

    final role = (data['role'] as String? ?? '').trim().toLowerCase();
    return role == 'driver';
  }

  String mapAuthError(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Unable to sign in right now. Please try again.';
    }
  }
}
