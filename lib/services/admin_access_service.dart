import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

class AdminAccessResult {
  const AdminAccessResult({required this.isAdmin, this.message});

  final bool isAdmin;
  final String? message;
}

class AdminAccessService {
  const AdminAccessService();

  Future<bool> isCurrentUserAdmin() async {
    final result = await checkCurrentUserAdmin();
    return result.isAdmin;
  }

  Future<AdminAccessResult> checkCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AdminAccessResult(
        isAdmin: false,
        message: 'Please sign in with an admin account.',
      );
    }

    final idTokenResult = await user.getIdTokenResult(true);
    final claims = idTokenResult.claims ?? const <String, dynamic>{};
    if (_isTruthy(claims['admin']) || _isTruthy(claims['isAdmin'])) {
      return const AdminAccessResult(isAdmin: true);
    }

    final userDoc = await db.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data != null &&
        (_hasAdminRole(data) ||
            _isTruthy(data['isAdmin']) ||
            _isTruthy(data['admin']))) {
      return const AdminAccessResult(isAdmin: true);
    }

    final email = user.email ?? 'this email';
    if (!userDoc.exists) {
      return AdminAccessResult(
        isAdmin: false,
        message:
            '$email is authenticated, but no admin profile exists in Firestore.',
      );
    }

    final role = (data?['role'] ?? data?['userRole'] ?? data?['accountType'])
        .toString()
        .trim();
    return AdminAccessResult(
      isAdmin: false,
      message:
          '$email is authenticated, but its Firestore role is "$role" instead of "admin".',
    );
  }

  bool _hasAdminRole(Map<String, dynamic> data) {
    final role = (data['role'] ?? data['userRole'] ?? data['accountType'])
        .toString()
        .trim()
        .toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'super_admin' ||
        role == 'superadmin';
  }

  bool _isTruthy(Object? value) {
    if (value == true) return true;
    if (value is num) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == '1' ||
          normalized == 'admin';
    }
    return false;
  }
}
