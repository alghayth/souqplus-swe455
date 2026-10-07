import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/models/app_notification.dart';
import 'package:souqplus/services/notification_logger.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return db.collection('users').doc(uid).collection('notifications');
  }

  Stream<List<AppNotification>> notificationsStream(String uid) {
    return _notificationsRef(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      final items = <AppNotification>[];
      for (final doc in snapshot.docs) {
        try {
          items.add(AppNotification.fromDoc(doc));
        } catch (e, s) {
          NotificationLogger.error(
            'SKIPPED MALFORMED NOTIFICATION ${doc.id}',
            e,
            s,
          );
        }
      }
      return items;
    });
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
    try {
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
    } catch (e, s) {
      NotificationLogger.error('PAYMENT NOTIFICATION WRITE ERROR', e, s);
      // Critical: let the checkout flow decide how to handle the failure.
      rethrow;
    }
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _notificationsRef(userId).doc(notificationId).set({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      NotificationLogger.error('MARK AS READ ERROR ($notificationId)', e, s);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _notificationsRef(
        userId,
      ).where('isRead', isEqualTo: false).get();

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
    } catch (e, s) {
      NotificationLogger.error('MARK ALL AS READ ERROR', e, s);
    }
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
    } catch (e, s) {
      NotificationLogger.error('SYSTEM NOTIFICATION WRITE ERROR', e, s);
    }
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;
}
