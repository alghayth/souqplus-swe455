import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/services/notification_service.dart';

const _uid = 'user-1';
final _service = NotificationService.instance;

// Reads are always allowed; writes only while a (fake) auth user is present.
// Tests seed data while "signed in", then sign out so every write is denied.
const _rules = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
''';

final _auth = StreamController<Map<String, dynamic>?>.broadcast();
late FakeFirebaseFirestore _fake;

CollectionReference<Map<String, dynamic>> _notifications() =>
    _fake.collection('users').doc(_uid).collection('notifications');

Future<void> _signIn() async {
  _auth.add({'uid': _uid});
  await Future<void>.delayed(Duration.zero);
}

Future<void> _signOut() async {
  _auth.add(null);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(() {
    _fake = FakeFirebaseFirestore(
      securityRules: _rules,
      authObject: _auth.stream,
    );
    db = _fake;
  });

  setUp(_signOut);

  test('control: writes are really denied while signed out', () async {
    await expectLater(
      _notifications().doc('x').set({'a': 1}),
      throwsA(anything),
    );
  });

  test('createPaymentConfirmationNotification rethrows (critical)', () async {
    await expectLater(
      _service.createPaymentConfirmationNotification(
        userId: _uid,
        orderId: 'abcdef123',
        paymentIntentId: 'pi_1',
        amountSar: 50,
      ),
      throwsA(anything),
    );
  });

  test('markAsRead swallows the error (non-critical)', () async {
    await _signIn();
    await _notifications().doc('n1').set({'title': 'N', 'isRead': false});
    await _signOut();

    await expectLater(
      _service.markAsRead(userId: _uid, notificationId: 'n1'),
      completes,
    );
    expect((await _notifications().doc('n1').get())['isRead'], isFalse);
  });

  test('markAllAsRead swallows a failed batch commit', () async {
    await _signIn();
    await _notifications().doc('n2').set({'title': 'N', 'isRead': false});
    await _signOut();

    await expectLater(_service.markAllAsRead(_uid), completes);
    expect((await _notifications().doc('n2').get())['isRead'], isFalse);
  });

  test('createSystemNotification swallows the error', () async {
    await expectLater(
      _service.createSystemNotification(userId: _uid, title: 't', message: 'm'),
      completes,
    );
  });
}
