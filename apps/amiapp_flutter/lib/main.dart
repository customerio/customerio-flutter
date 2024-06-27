import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'src/app.dart';
import 'src/auth.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin localNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FCM (flutter-fire)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// Update the iOS foreground notification presentation options to allow
  /// heads up notifications.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  var initSettingsAndroid = AndroidInitializationSettings("app_icon");
  var initSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
      debugPrint('local notification: $id, $title, $body, $payload');
    }
  );
  var initSettings = InitializationSettings(
    android: initSettingsAndroid,
    iOS: initSettingsIOS,
  );
  await localNotificationsPlugin.initialize(
    initSettings,
    // ignore: missing_return
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      debugPrint('notification: $notificationResponse');
    }
  );

  // Load SDK configurations
  await dotenv.load(fileName: ".env");
  // Wait for user state to be updated
  AmiAppAuth auth = AmiAppAuth();
  await auth.updateState();
  // Initialize and run app
  runApp(AmiApp(auth: auth));
}
