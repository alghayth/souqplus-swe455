import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

class AdminAccessService {
  const AdminAccessService();

  Future<bool> isCurrentUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final userDoc = await db.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final role = (data?['role'] as String? ?? '').trim().toLowerCase();
    final isAdmin = data?['isAdmin'] == true;
    return role == 'admin' || isAdmin;
  }
}
