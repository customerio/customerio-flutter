import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'src/app.dart';
import 'src/auth.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FCM (flutter-fire)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load SDK configurations
  await dotenv.load(fileName: ".env");
  // Wait for user state to be updated
  AmiAppAuth auth = AmiAppAuth();
  await auth.updateState();
  // Initialize and run app
  runApp(AmiApp(auth: auth));
}
