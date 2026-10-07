# Program Comprehension — Notifications Module

**System:** SouqPlus (Flutter + Firebase: Firestore, Auth, Cloud Messaging)
**Module:** Notifications (in-app notification list and push notifications)

## 1. Purpose

The module tells users about events that matter to them: payment
confirmations, order status changes (for example "in transit" and
"delivered"), and system messages from the admin. Users see the
notifications in two places:

- **In-app:** a list on the Notifications screen with a read/unread state, and
  an unread badge in the home header.
- **Push:** device notifications through Firebase Cloud Messaging (FCM),
  including a local notification shown while the app is open (foreground).

## 2. Files and responsibilities

| File | Responsibility |
|---|---|
| `lib/services/notification_service.dart` | Firestore access for in-app notifications: stream the list, count unread, create payment and system notifications, mark one or all as read. |
| `lib/services/push_notification_service.dart` | Push setup at app start: permission request, local-notification plugin and Android channel, foreground and opened-app listeners, saving the FCM token when the auth state changes. |
| `lib/services/push_token_service.dart` | Saves the user's FCM token after sign-in or registration, and again whenever the token is refreshed. |
| `lib/services/notification_logger.dart` | *(Added by MR001.)* One shared error logger for the module, built on `dart:developer`. |
| `lib/models/app_notification.dart` | `AppNotification` model; `fromDoc` converts a Firestore document into the model. |
| `lib/screens/notifications/notifications_screen.dart` | UI: the list, the total and unread counters, "Mark all read", and marking one notification as read when it is tapped. |
| `lib/components/notification_popup_listener.dart` | Shows an in-app popup when a new notification arrives. |
| `functions/index.js` | Cloud Functions: `createOrderWorkflowNotifications` writes order-status notifications, `sendPushOnNotificationCreated` sends an FCM push for every new notification document, and `sendnotificationtousers` lets the admin send a broadcast. |

## 3. Data model

Firestore path: `users/{uid}/notifications/{notificationId}`

| Field | Type | Notes |
|---|---|---|
| `type` | string | `payment_confirmation`, `system_update`, order status types, and so on |
| `title`, `message` | string | Text shown in the list |
| `isRead` | bool | Unread when `false` |
| `createdAt` | timestamp | Sort key (newest first) |
| `readAt` | timestamp | Set when the notification is marked as read |
| `orderId`, `paymentIntentId`, `amountSar` | optional | Only on payment notifications |

FCM tokens are stored on `users/{uid}` as `fcmTokens` (an array),
`latestFcmToken`, and `fcmTokenUpdatedAt`.

## 4. Main flows

1. **App start:** `main.dart` calls `PushNotificationService.initialize()`.
   It asks for permission, sets up the local notifications, registers the
   listeners, and saves the token for the current user.
2. **Sign-in or registration:** `PushTokenService.saveUserFcmToken()` saves the
   token and starts listening for token refreshes.
3. **Payment:** `checkout_screen.dart` calls
   `createPaymentConfirmationNotification`, which creates a Firestore document.
   The Cloud Function `sendPushOnNotificationCreated` then sends the push.
4. **Order status change:** a Cloud Function writes the notification document,
   and the push is sent the same way.
5. **Reading:** `notificationsStream` feeds the screen, and
   `unreadCountStream` feeds the home badge. Tapping a notification calls
   `markAsRead`. "Mark all read" calls `markAllAsRead`, which updates all
   unread notifications in one batch.

## 5. Dependencies

- `cloud_firestore`, `firebase_auth`, `firebase_messaging`,
  `flutter_local_notifications`
- Firebase Cloud Functions (Node.js) on the server side
- Callers: `main.dart`, `checkout_screen.dart`, `notifications_screen.dart`,
  `home_header.dart`, `sign_form.dart`, `registration_form.dart`,
  `home_screen.dart`

## 6. Weaknesses found (input to MR001)

Several asynchronous operations had **no error handling or logging**. When
they failed, nothing reported the failure (no message and no log entry).
Some of them could even break app startup or the whole notifications list.
`createSystemNotification`, `_saveToken` and `_saveTokenForUser` already used
`try/catch` and served as the reference pattern. The full list is in
[MR001 — Maintenance Request Form](../maintenance-requests/MR001-preventive-notifications/1-maintenance-request-form.md).
