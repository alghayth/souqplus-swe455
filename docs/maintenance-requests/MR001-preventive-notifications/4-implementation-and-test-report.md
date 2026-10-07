# Implementation and Test Report — MR001

**Branch:** `person1-notifications-mr` · **Date:** 2026-10-07

## 1. Changes made

### `lib/services/notification_service.dart`
| Function | Change | Type |
|---|---|---|
| `createPaymentConfirmationNotification` | `try/catch`, logs the error, then `rethrow` | Critical |
| `markAsRead` | `try/catch`, logs the error and continues | Non-critical |
| `markAllAsRead` | The whole body, including `batch.commit()`, is in `try/catch`; logs and continues | Non-critical |
| `notificationsStream` | Each document is converted inside its own `try/catch`; a malformed document is skipped and logged | Non-critical |
| `createSystemNotification` | Already protected; now uses `NotificationLogger` and records the stack trace | — |

### `lib/services/push_notification_service.dart`
| Function | Change |
|---|---|
| `initialize()` | All setup after the `kIsWeb` check is in `try/catch`; app startup continues if setup fails |
| `_showForegroundNotification` | `_localNotifications.show(...)` is in `try/catch` |
| `_saveToken`, `_saveTokenForUser` | Already protected; now use `NotificationLogger` and record the stack trace |

### `lib/services/push_token_service.dart`
| Location | Change |
|---|---|
| `onTokenRefresh` listener | The write inside the listener is in its own `try/catch`. The outer `try/catch` does not cover it, because the listener runs later. |

### `lib/services/notification_logger.dart` (new)
`NotificationLogger.error(message, error, stack)` writes through
`dart:developer` with the name `Notifications` and level 1000 (error). The
messages appear in Flutter DevTools (Logging tab) and in the IDE debug
console. They do not appear in the `flutter run` terminal output.

## 2. Automated tests

Command: `flutter test` → **12/12 passed** (1 existing test and 11 new ones).
Command: `flutter analyze` → **No issues found.**

New tests use `fake_cloud_firestore` (an in-memory Firestore):

| File | Test | Result |
|---|---|---|
| `notification_service_test.dart` | Payment notification is written correctly | ✅ |
| | `markAsRead` sets `isRead = true` and `readAt` | ✅ |
| | `markAllAsRead` clears all unread notifications | ✅ |
| | `markAllAsRead` with nothing unread completes | ✅ |
| | Stream skips a malformed document and keeps the rest | ✅ |
| | Unread count ignores malformed documents | ✅ |
| `notification_service_failure_test.dart` (security rules deny writes) | Control: writes really are denied | ✅ |
| | Payment notification **rethrows** on failure | ✅ |
| | `markAsRead` **does not throw** on failure, and the data is unchanged | ✅ |
| | `markAllAsRead` **does not throw** when the batch commit fails | ✅ |
| | `createSystemNotification` does not throw on failure | ✅ |

## 3. Manual testing (Android emulator, API 36, signed-in test account)

| # | Scenario | Expected | Result |
|---|---|---|---|
| 1 | Start the app | App starts normally, no notification errors | ✅ |
| 2 | Sign in | FCM token saved (`FCM TOKEN: saved for user …`) | ✅ |
| 3 | Open the Notifications screen | List loads (1176 total, 1168 unread) | ✅ |
| 4 | Tap an unread notification | Blue dot disappears; unread goes from 1168 to 1167 | ✅ |
| 5 | Tap "Mark all read" | Unread goes from 1167 to 0 | ✅ |
| 6 | **Failure test:** collection path temporarily changed to an invalid path | Screen shows "Could not load notifications: permission-denied"; "Mark all read" does not crash; the app keeps running | ✅ |
| 7 | Correct path restored, analysis and tests run again | No issues, 12/12 tests pass | ✅ |

## 4. Out of scope (found during testing)

- `MarketplaceCleanupService._purgeInvalidProducts`
  (`lib/services/marketplace_cleanup_service.dart:28`) throws an **unhandled
  `permission-denied`** every time the Home screen opens, because it reads
  other users' documents. This is outside the Notifications module and is a
  candidate for a separate corrective MR.
- `lib/components/notification_popup_listener.dart:70` calls
  `AppNotification.fromDoc` without protection. It could get the same
  per-document hardening in a follow-up preventive MR.
