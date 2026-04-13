import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/models/app_notification.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return db.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _notificationsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotification.fromDoc)
              .toList(growable: false),
        );
  }

  Stream<int> unreadCountStream(String uid) {
    return notificationsStream(uid).map(
      (notifications) => notifications.where((item) => !item.isRead).length,
    );
  }

  Future<void> createPaymentConfirmationNotification({
    required String userId,
    required String orderId,
    required String paymentIntentId,
    required double amountSar,
  }) async {
    await _notificationsRef(userId).add({
      'type': 'payment_confirmation',
      'title': 'Payment confirmed',
      'message':
          'Your payment was successful. Order #${orderId.substring(0, 6).toUpperCase()} has been placed.',
      'orderId': orderId,
      'paymentIntentId': paymentIntentId,
      'amountSar': amountSar,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _notificationsRef(userId).doc(notificationId).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsRef(userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = db.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await _notificationsRef(userId).add({
        'type': 'system_update',
        'title': title,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SYSTEM NOTIFICATION WRITE ERROR: $e');
    }
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;
}
