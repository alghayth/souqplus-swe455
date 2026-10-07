# Form 2 — Impact Analysis Form

| Field | Value |
|---|---|
| **MR ID** | MR001 |
| **Current State** | Notification writes, push initialization, local-notification display, and FCM token-refresh writes run without try/catch or logging. A single malformed notification document can break the entire notifications stream. Failures happen silently. |
| **Future State** | All asynchronous notification operations are wrapped in try/catch with consistent logging. Malformed documents are skipped one at a time, so one bad document no longer breaks the list. Critical operations (payment confirmation) log the error and rethrow it; non-critical operations log the error and continue. |
| **Gap / Required Change** | Add try/catch and logging to `createPaymentConfirmationNotification`, `markAsRead`, `markAllAsRead`, `initialize()`, `_showForegroundNotification`, and the `onTokenRefresh` listener. Make the `notificationsStream` conversion safe for each document. (Optional) add a shared logger. |
| **Alternative Solutions** | 1) A global handler through `FlutterError.onError` / `runZonedGuarded` (broad, less targeted). 2) A crash-reporting package such as Firebase Crashlytics (powerful, but a larger scope). **Chosen:** targeted try/catch and a lightweight logger, which has the lowest risk. |
| **Timing of Impact** | ☑ Immediate ☐ Short-term ☐ Long-term |
| **Level of Impact** | ☑ Low ☐ Medium ☐ High |
| **Type of Impact** | ☑ Functional ☐ UI/UX ☐ Performance ☐ Security ☐ Other: ____ |
| **Scale of Change** | ☐ Organization ☐ Program ☐ Project ☑ Module |
| **Module / Component** | Notifications module: `notification_service.dart`, `push_notification_service.dart`, `push_token_service.dart`, and the new `notification_logger.dart`. New unit tests are in `test/services/`. |
| **Dependencies & Affected Components** | Cloud Firestore (`users/{uid}/notifications`), Firebase Cloud Messaging (FCM), `flutter_local_notifications`. Affected callers: the checkout flow (calls the payment-confirmation notification), the notifications screen and the home header (both use the stream), and `main.dart` (calls `initialize()` at startup). |
| **Key Risks** | Low. The change is purely defensive and does not alter behavior when operations succeed. A catch that is too broad could hide a bug during development; this is reduced by logging every caught error. Rethrowing on the payment notification keeps the existing checkout error handling. |
| **Roles Affected** | End users (more reliable notifications), developers (easier debugging), testers. |
| **Number Affected** | All app users rely on notifications. The code change is small (3–4 files, one module). |
| **Communication Requirements** | The team is informed through the Pull Request description and a short note in the team meeting. |
| **Training Requirements** | No. |
| **Leadership Oversight** | The team lead or course instructor reviews the Pull Request. |
| **Alignment & Collaboration Needed** | Light coordination with Person 4 (Payments), because the payment-confirmation notification is triggered from the checkout flow. |
| **Resources Required** | 1 developer, the existing Flutter/Dart tooling, and the existing Firebase project. No new software or paid services. (`fake_cloud_firestore` is added as a free, test-only dev dependency.) |
