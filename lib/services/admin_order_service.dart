import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:souqplus/main.dart';

class AdminOrderService {
  const AdminOrderService();

  static const List<String> orderLifecycle = [
    'ordered',
    'in transit',
    'delivered',
  ];

  static const List<String> paymentLifecycle = [
    'paid',
    'unpaid',
    'refunded',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> ordersStream() {
    return db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
}
