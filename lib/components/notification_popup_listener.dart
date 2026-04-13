import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/models/app_notification.dart';
import 'package:souqplus/screens/notifications/notifications_screen.dart';

class NotificationPopupListener extends StatefulWidget {
  const NotificationPopupListener({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationPopupListener> createState() =>
      _NotificationPopupListenerState();
}

class _NotificationPopupListenerState extends State<NotificationPopupListener> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  bool _hasLoadedInitialNotifications = false;
  bool _isShowingPopup = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
    );
    _handleAuthChanged(FirebaseAuth.instance.currentUser);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthChanged(User? user) {
    _notificationSubscription?.cancel();
    _hasLoadedInitialNotifications = false;

    if (user == null) {
      return;
    }

    _notificationSubscription = db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(_handleNotificationSnapshot);
  }

  void _handleNotificationSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!_hasLoadedInitialNotifications) {
      _hasLoadedInitialNotifications = true;
      return;
    }

    final addedNotifications = snapshot.docChanges
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) => AppNotification.fromDoc(change.doc))
        .toList();

    if (addedNotifications.isEmpty) {
      return;
    }

    addedNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _showNotificationPopup(addedNotifications.first);
  }

  Future<void> _showNotificationPopup(AppNotification notification) async {
    final navigator = rootNavigatorKey.currentState;
    final dialogContext = rootNavigatorKey.currentContext;

    if (!mounted ||
        _isShowingPopup ||
        navigator == null ||
        dialogContext == null) {
      return;
    }

    _isShowingPopup = true;
    try {
      await showDialog<void>(
        context: dialogContext,
        builder: (alertContext) => AlertDialog(
          title: Text(notification.title),
          content: Text(
            notification.message.isEmpty
                ? 'You have a new notification.'
                : notification.message,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(alertContext).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(alertContext).pop();
                navigator.pushNamed(NotificationsScreen.routeName);
              },
              child: const Text('View'),
            ),
          ],
        ),
      );
    } finally {
      _isShowingPopup = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
