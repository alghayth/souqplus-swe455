import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:souqplus/firebase_options.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/screens/notifications/notifications_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'souqplus_notifications',
        'Souqplus notifications',
        description: 'Order confirmations and system updates from Souqplus.',
        importance: Importance.high,
      );

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) => _openNotificationsScreen(),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _openNotificationsScreen(),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openNotificationsScreen();
    }

    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _saveTokenForUser(user),
    );
    await _saveTokenForUser(FirebaseAuth.instance.currentUser);

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _saveToken(user: user, token: token);
      }
    });
  }

  Future<void> _saveTokenForUser(User? user) async {
    if (user == null) {
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _saveToken(user: user, token: token);
    } catch (e) {
      debugPrint('FCM TOKEN SAVE ERROR: $e');
    }
  }

  Future<void> _saveToken({required User user, required String token}) async {
    try {
      await db.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'latestFcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM TOKEN WRITE ERROR: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Souqplus';
    final body =
        notification?.body ??
        message.data['message'] ??
        'You have a new update.';

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'souqplus_notifications',
          'Souqplus notifications',
          channelDescription:
              'Order confirmations and system updates from Souqplus.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _openNotificationsScreen() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamed(NotificationsScreen.routeName);
  }
}
