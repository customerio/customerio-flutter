import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CustomerIO.initialize(
    config: CustomerIOConfig(
      siteId: "YOUR_SITE_ID",
      apiKey: "YOUR_API_KEY",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    CustomerIO.identify(
        identifier: "flutter-example",
        attributes: {"name": "Flutter CIO", "email": "example@flutter.io"});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Column(
            children: <Widget>[
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('TRACK EVENT'),
                  onPressed: () {
                    CustomerIO.track(name: "ButtonClick", attributes: {
                      'stringType': 'message',
                      'numberType': 123,
                      'booleanType': true,
                    });
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('TRACK SCREEN'),
                  onPressed: () {
                    CustomerIO.screen(name: "LoginScreen", attributes: {
                      "loggedIn": false,
                    });
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('SET DEVICE ATTRIBUTES'),
                  onPressed: () {
                    CustomerIO.setDeviceAttributes(
                        attributes: {"wifi_connected": true, "region": "us"});
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('SET PROFILE ATTRIBUTES'),
                  onPressed: () {
                    CustomerIO.setProfileAttributes(
                        attributes: {"age": 31, "height": 5.9, "gender": "M"});
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                    child: const Text('CLEAR IDENTITY'),
                    onPressed: () {
                      CustomerIO.clearIdentify();
                    }),
              ),
              const Spacer(),
            ],
          )),
    );
  }
}
