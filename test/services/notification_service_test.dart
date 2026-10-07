import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/notification_service.dart';

const _uid = 'user-1';
final _service = NotificationService.instance;

late FakeFirebaseFirestore _fake;

CollectionReference<Map<String, dynamic>> _notifications() =>
    _fake.collection('users').doc(_uid).collection('notifications');

void main() {
  // `db` is a late final global, so it is assigned once for the whole file
  // and each test clears the data instead of swapping instances.
  setUpAll(() {
    _fake = FakeFirebaseFirestore();
    db = _fake;
  });

  setUp(() async {
    final existing = await _notifications().get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }
  });

  group('createPaymentConfirmationNotification', () {
    test('writes the notification on success', () async {
      await _service.createPaymentConfirmationNotification(
        userId: _uid,
        orderId: 'abcdef123',
        paymentIntentId: 'pi_1',
        amountSar: 50,
      );

      final docs = (await _notifications().get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single['type'], 'payment_confirmation');
      expect(docs.single['message'], contains('#ABCDEF'));
      expect(docs.single['isRead'], isFalse);
    });
  });

  group('markAsRead', () {
    test('marks the notification as read on success', () async {
      final ref = await _notifications().add({
        'title': 'Hi',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      await _service.markAsRead(userId: _uid, notificationId: ref.id);

      final doc = await ref.get();
      expect(doc['isRead'], isTrue);
      expect(doc.data(), contains('readAt'));
    });
  });

  group('markAllAsRead', () {
    test('marks every unread notification as read', () async {
      for (var i = 0; i < 3; i++) {
        await _notifications().add({
          'title': 'N$i',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
      }

      await _service.markAllAsRead(_uid);

      final unread = await _notifications()
          .where('isRead', isEqualTo: false)
          .get();
      expect(unread.docs, isEmpty);
    });

    test('does nothing when there are no unread notifications', () async {
      await expectLater(_service.markAllAsRead(_uid), completes);
    });
  });

  group('notificationsStream', () {
    test('skips a malformed document instead of failing the list', () async {
      await _notifications().doc('good').set({
        'title': 'Good',
        'message': 'ok',
        'isRead': false,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
      });
      await _notifications().doc('bad').set({
        // title must be a String; a number makes AppNotification.fromDoc throw.
        'title': 123,
        'isRead': false,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      });

      final items = await _service.notificationsStream(_uid).first;
      expect(items.map((n) => n.id), ['good']);
    });

    test('unread count ignores malformed documents', () async {
      await _notifications().doc('good').set({
        'title': 'Good',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
      await _notifications().doc('bad').set({
        'title': 123,
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      expect(await _service.unreadCountStream(_uid).first, 1);
    });
  });
}
