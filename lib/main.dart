import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screen/splash_screen.dart';
import 'services/push_notification_service.dart'; 

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Runs in a separate isolate; keep it minimal.
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  // Tells Flutter to get itself ready before we run any setup
  // code. Without this line, Firebase.initializeApp() crashes.
  WidgetsFlutterBinding.ensureInitialized();

  // Connects your app to your Firebase project (agritrade-bef87).
  // If this is missing, you get the error:
  //   "No Firebase App '[DEFAULT]' has been created"
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background messaging handler (when app is closed or in background)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- NEW: Initialize Push Notifications ---
  final pushService = PushNotificationService();
  await pushService.setupFCM();

  // --- NEW: Handle Foreground Messages ---
  // Listen for messages while the app is actively open on the screen
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a foreground message: ${message.data}');
    
    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification?.title}');
      // Optional: You can use a GlobalKey<ScaffoldMessengerState> here to show 
      // an in-app Snackbar when they receive a message while using the app!
    }
  });

  runApp(const AgriTradeApp());
}

class AgriTradeApp extends StatelessWidget {
  const AgriTradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriTrade+',

      // Hides the red "DEBUG" ribbon in the corner.
      debugShowCheckedModeBanner: false,

      // One line = Montserrat everywhere, plus your green theme.
      theme: AppTheme.themeData(),

      // THIS is what replaces the demo counter page.
      home: const SplashScreen(),
    );
  }
}