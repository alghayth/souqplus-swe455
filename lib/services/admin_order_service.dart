import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';

class AdminOrderService {
  const AdminOrderService();

  static const List<String> orderLifecycle = [
    'ordered',
    'in transit',
    'delivered',
  ];

  static const List<String> paymentLifecycle = ['paid', 'unpaid', 'refunded'];

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream() {
    return db.collection('orders').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> productsStream() {
    return db.collection('products').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return db.collection('users').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> categoriesStream() {
    return db.collection('categories').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> driversStream() {
    return db.collection('drivers').snapshots();
  }

  static String normalizeOrderStatus(String value) {
    final status = value.trim().toLowerCase();
    return switch (status) {
      'ordered' || 'pending' || 'confirmed' => 'ordered',
      'in transit' || 'in_transit' || 'shipped' => 'in transit',
      'delivered' => 'delivered',
      _ => status,
    };
  }

  Future<void> updateOrderField({
    required String orderId,
    required String field,
    required String value,
  }) {
    return db.collection('orders').doc(orderId).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserBlocked({
    required String userId,
    required bool blocked,
  }) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return db.collection('users').doc(userId).set({
      'isBlocked': blocked,
      'updatedAt': FieldValue.serverTimestamp(),
      if (blocked) ...{
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': adminUid,
      } else ...{
        'unblockedAt': FieldValue.serverTimestamp(),
        'unblockedBy': adminUid,
      },
    }, SetOptions(merge: true));
  }

  Future<void> removeProductPost({required String productId}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'removeProductPostAsAdmin',
    );
    return callable.call({'productId': productId});
  }

  Future<void> removeDriver({required String driverId}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'removeDriverAsAdmin',
    );
    return callable.call({'driverId': driverId});
  }
}
