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
  runApp(const Agp8MinApp());
}

class Agp8MinApp extends StatelessWidget {
  const Agp8MinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGP 8 Min',
      home: Scaffold(
        body: Center(child: Text('CIO Flutter AGP 8 build smoke test')),
      ),
    );
  }
}
