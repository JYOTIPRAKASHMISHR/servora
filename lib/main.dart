import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:servora/services/notification_service.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

// ============================================================
// GLOBAL NAVIGATOR KEY
// Used for notification tap navigation
// ============================================================

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FIREBASE
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  await NotificationService.initialize(
    navigationKey: navigatorKey,
  );
  await NotificationService.saveToken();

  NotificationService.listenTokenRefresh();

  // ============================================================
  // RUN APP
  // ============================================================

  runApp(const Servora());
}

class Servora extends StatelessWidget {
  const Servora({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: "Servora",

      // ========================================================
      // GLOBAL NAVIGATOR KEY
      // NotificationService uses this when notification
      // is tapped.
      // ========================================================

      navigatorKey: navigatorKey,

      theme: AppTheme.theme,

      home: const SplashScreen(),
    );
  }
}