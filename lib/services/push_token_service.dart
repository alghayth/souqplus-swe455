import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:souqplus/main.dart';

class PushTokenService {
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static Future<void> saveUserFcmToken({
    String collectionPath = 'users',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('FCM TOKEN: no signed-in user yet.');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM TOKEN: permission is ${settings.authorizationStatus}.');

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM TOKEN: Firebase returned no token.');
        return;
      }

      final userRef = db.collection(collectionPath).doc(user.uid);

      await userRef.set({
        'latestFcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM TOKEN: saved for user ${user.uid}.');

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) async {
            await userRef.set({
              'latestFcmToken': newToken,
              'fcmTokens': FieldValue.arrayUnion([newToken]),
              'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            debugPrint('FCM TOKEN: refreshed for user ${user.uid}.');
          });
    } catch (e) {
      debugPrint('FCM TOKEN ERROR: $e');
    }
  }
}
