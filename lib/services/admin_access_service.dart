import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

class AdminAccessResult {
  const AdminAccessResult({
    required this.isAdmin,
    this.message,
  });

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

    final userDoc = await db.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final role = (data?['role'] as String? ?? '').trim().toLowerCase();
    final isAdmin = data?['isAdmin'] == true;
    if (role == 'admin' || isAdmin) {
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

    return AdminAccessResult(
      isAdmin: false,
      message:
          '$email is authenticated, but its Firestore role is "$role" instead of "admin".',
    );
  }
}
