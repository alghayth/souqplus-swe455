import 'dart:developer' as developer;

class NotificationLogger {
  NotificationLogger._();

  static void error(String message, [Object? error, StackTrace? stack]) {
    developer.log(
      message,
      name: 'Notifications',
      level: 1000,
      error: error,
      stackTrace: stack,
    );
  }
}
