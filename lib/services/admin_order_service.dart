import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  Stream<QuerySnapshot<Map<String, dynamic>>> driverOrdersStream({
    required String driverId,
  }) {
    return db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> orderStream({
    required String orderId,
  }) {
    return db.collection('orders').doc(orderId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> orderTrackingPointsStream({
    required String orderId,
    int limit = 250,
  }) {
    return db
        .collection('orders')
        .doc(orderId)
        .collection('tracking_points')
        .orderBy('recordedAtMs')
        .limitToLast(limit)
        .snapshots();
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
      'delivered' || 'complete' || 'completed' => 'delivered',
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

  Future<void> updateDriverLiveLocation({
    required List<String> orderIds,
    required double latitude,
    required double longitude,
  }) async {
    if (orderIds.isEmpty) return;

    final batch = db.batch();
    final driverLocation = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'geoPoint': GeoPoint(latitude, longitude),
    };

    for (final orderId in orderIds) {
      final orderRef = db.collection('orders').doc(orderId);
      batch.update(orderRef, {
        'driverCurrentLocation': driverLocation,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint(
      'Backend: Sent location current=($latitude, $longitude) orders=${orderIds.join(",")}',
    );
  }

  Future<void> appendDriverTrackingPoints({
    required List<String> orderIds,
    required double latitude,
    required double longitude,
    required int recordedAtMs,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    if (orderIds.isEmpty) return;

    final batch = db.batch();
    for (final orderId in orderIds) {
      final pointRef = db
          .collection('orders')
          .doc(orderId)
          .collection('tracking_points')
          .doc();
      batch.set(pointRef, {
        'latitude': latitude,
        'longitude': longitude,
        'geoPoint': GeoPoint(latitude, longitude),
        'recordedAtMs': recordedAtMs,
        'createdAt': FieldValue.serverTimestamp(),
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (accuracy != null) 'accuracy': accuracy,
      });
    }

    await batch.commit();
    debugPrint(
      'Backend: Sent location trail=($latitude, $longitude) '
      'recordedAtMs=$recordedAtMs orders=${orderIds.join(",")}',
    );
  }

  Future<void> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required String driverName,
    required String driverEmail,
    required String driverPhoneNumber,
  }) {
    return db.collection('orders').doc(orderId).update({
      'driverId': driverId,
      'driverName': driverName,
      'driverEmail': driverEmail,
      'driverPhoneNumber': driverPhoneNumber,
      'assignedAt': FieldValue.serverTimestamp(),
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

  Future<void> removeUser({required String userId}) {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'removeUserAsAdmin',
    );
    return callable.call({'userId': userId});
  }

  Future<void> updateDriverBlocked({
    required String driverId,
    required bool blocked,
  }) {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return db.collection('drivers').doc(driverId).set({
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

  Future<int> inTransitOrderCountForDriver({required String driverId}) async {
    final snapshot = await db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .get();
    return snapshot.docs.where((doc) {
      final status = normalizeOrderStatus(
        (doc.data()['status'] as String?) ?? '',
      );
      return status == 'in transit';
    }).length;
  }

  Future<int> activeAssignedOrderCountForDriver({
    required String driverId,
  }) async {
    final snapshot = await db
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .get();
    return snapshot.docs.where((doc) {
      final status = normalizeOrderStatus(
        (doc.data()['status'] as String?) ?? '',
      );
      return status != 'delivered';
    }).length;
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
