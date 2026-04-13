import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:souqplus/main.dart';

class AdminOrderService {
  const AdminOrderService();

  static const List<String> orderLifecycle = [
    'pending',
    'confirmed',
    'shipped',
    'delivered',
    'cancelled',
  ];

  static const List<String> paymentLifecycle = [
    'paid',
    'unpaid',
    'refunded',
  ];

  static const List<String> transferLifecycle = [
    'pending',
    'transferred',
    'failed',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream() {
    return db.collection('orders').orderBy('createdAt', descending: true).snapshots();
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
}
