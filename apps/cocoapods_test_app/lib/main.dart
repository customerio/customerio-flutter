import 'package:flutter/material.dart';
import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initCustomerIO();
  }

  Future<void> _initCustomerIO() async {
    try {
      final config = CustomerIOConfig(
        cdpApiKey: 'test-cdp-api-key',
        region: Region.us,
      );
      CustomerIO.initialize(config: config);
      setState(() => _status = 'Customer.io SDK initialized via CocoaPods ✅');
    } catch (e) {
      setState(() => _status = 'Init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('CocoaPods Validation App')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_status, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
