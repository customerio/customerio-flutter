import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CustomerIO.initialize(
    config: CustomerIOConfig(
      cdpApiKey: 'placeholder',
      region: Region.us,
    ),
  );
  runApp(const Agp9TestApp());
}

class Agp9TestApp extends StatelessWidget {
  const Agp9TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGP 9 Test',
      home: Scaffold(
        body: Center(child: Text('CIO Flutter AGP 9 build smoke test')),
      ),
    );
  }
}
