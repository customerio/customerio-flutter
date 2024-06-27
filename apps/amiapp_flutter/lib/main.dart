import 'package:customer_io/customer_io.dart';
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

  // Setup flutter_local_notifications plugin to send local notifications and receive callbacks for them.
  var initSettingsAndroid = const AndroidInitializationSettings("app_icon");
  // The default settings will show local push notifications while app in foreground with plugin.
  var initSettingsIOS = const DarwinInitializationSettings();
  var initSettings = InitializationSettings(
    android: initSettingsAndroid,
    iOS: initSettingsIOS,
  );
  await localNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      // Callback from `flutter_local_notifications` plugin for when a local notification is clicked.
      // Unfortunately, we are only able to get the payload object for the local push, not anything else such as title or body.
      CustomerIO.track(name: "local push notification clicked", attributes: {"payload": notificationResponse.payload});
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
