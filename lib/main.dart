import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// Your project files
import 'components/notification_popup_listener.dart';
import 'theme.dart';
import 'routes.dart';
import 'screens/splash/splash_screen.dart';
import 'services/push_notification_service.dart';

// âœ… IMPORTANT: Use your Firestore database ID (the one you see in console: "souqplus")
const String kFirestoreDatabaseId = 'souqplus';

// âœ… Global Firestore reference to the correct DB
late final FirebaseFirestore db;
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ًں”¥ 1ï¸ڈâƒ£ Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ًں”¥ 2ï¸ڈâƒ£ Initialize Firestore with correct database
  db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: kFirestoreDatabaseId,
  );

  await PushNotificationService.instance.initialize();

  // ًں”¥ 3ï¸ڈâƒ£ Initialize Supabase
  try {
    await Supabase.initialize(
      url: 'https://drqqzlpmzzwenzrepqml.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRycXF6bHBtenp3ZW56cmVwcW1sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2NzgzNDcsImV4cCI6MjA4NzI1NDM0N30._1IQVd9jPOqgIgD_V6DeH75ERv76Tsj9u-hJgWXraSQ',
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Supabase initialization skipped: $e');
    }
  }

  // ًں”¥ 4ï¸ڈâƒ£ Debug settings
  if (kDebugMode) {
    final opts = Firebase.app().options;
    debugPrint('PROJECT ID: ${opts.projectId}');
    debugPrint('STORAGE BUCKET: ${opts.storageBucket}');
    debugPrint('FIRESTORE DB: $kFirestoreDatabaseId');

    if (kIsWeb) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
        forceRecaptchaFlow: true,
      );
    }
  }
  // Initialize Stripe
  Stripe.publishableKey =
      'pk_test_51TFyhFDofRwdp5SlRF0yc43vfI9IBFFUp2hH34WxUz4IQd2bF79HSvSj32ayPj3m8qa8Wwp8jepnEBx3H6hEtmVt00MhFS6Y2D';
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Souqplus App',
      theme: AppTheme.lightTheme(context),
      initialRoute: SplashScreen.routeName,
      routes: routes,
      builder: (context, child) =>
          NotificationPopupListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
