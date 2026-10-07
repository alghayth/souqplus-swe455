# Form 1 — Maintenance Request Form

**SWE 455 — Phase 1 · Part 2 — Maintenance Request (MR001)**
Preventive maintenance: strengthen error handling and logging in the Notifications module (SouqPlus) · Munirah

| Field | Value |
|---|---|
| **MR ID** | MR001 |
| **Date Logged** | 2026-10-07 |
| **Reported By** | Munirah |
| **Change / Request Name** | Strengthen error handling and logging in the Notifications module |
| **Description** | Wrap the asynchronous operations of the Notifications module (Firestore notification writes, FCM token updates, local-notification display, and push initialization) in try/catch blocks with consistent logging, and make the notifications stream parse each document safely. Expected outcome: notification failures are caught and logged instead of failing silently. This improves reliability and makes problems easier to debug, with no change in behavior when operations succeed. |
| **Justification** | Several notification operations currently run without any error handling or logging. Failures (for example a failed Firestore write, a malformed notification document, or a failed push setup at startup) therefore happen silently and are hard to detect. This preventive change reduces the risk of undetected failures in the future and makes problems traceable. |
| **Request Type** | ☐ Bug Fix<br>☐ Feature Enhancement<br>☐ Performance Optimization<br>☐ Security Update<br>☐ Compatibility Update<br>☑ Other: Reliability & logging improvement |
| **Maintenance Type** | ☐ Corrective<br>☐ Perfective<br>☐ Adaptive<br>☑ Preventive |
| **Severity** | ☐ High ☑ Medium ☐ Low |
| **Priority** | ☐ High ☑ Medium ☐ Low |

## Appendix — Problems found in the current code

| # | File | Function / location | Problem |
|---|---|---|---|
| 1 | `notification_service.dart` | `createPaymentConfirmationNotification` | Firestore write without try/catch |
| 2 | `notification_service.dart` | `markAsRead` | No error handling and no logging |
| 3 | `notification_service.dart` | `markAllAsRead` | `batch.commit()` not protected |
| 4 | `notification_service.dart` | `notificationsStream` | One malformed document breaks the whole list |
| 5 | `push_notification_service.dart` | `initialize()` | Push setup not protected; it runs at app start |
| 6 | `push_notification_service.dart` | `_showForegroundNotification` | Local notification display without try/catch |
| 7 | `push_token_service.dart` | `onTokenRefresh` listener | Token write inside the listener not protected |

`createSystemNotification`, `_saveToken` and `_saveTokenForUser` already used
try/catch, and their pattern was used as the reference.

**Rule applied:** critical operations (the payment confirmation) log the error
and `rethrow` so the caller decides what to do. Non-critical operations (mark
as read, display, token refresh, push setup) log the error and continue.
