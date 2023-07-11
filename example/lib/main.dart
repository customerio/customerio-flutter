import 'dart:async';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_inapp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CustomerIO.initialize(
    config: CustomerIOConfig(
        siteId: "SITE_ID",
        apiKey: "API_KEY",
        logLevel: CioLogLevel.debug,
        enableInApp: true,
        autoTrackDeviceAttributes: true,
        autoTrackPushEvents: true),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription inAppMessageStreamSubscription;

  @override
  void dispose() {
    /// Stop listening to streams
    inAppMessageStreamSubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    CustomerIO.identify(
        identifier: "identifier", attributes: {"email": "email"});
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
                  child: const Text('REGISTER DEVICE'),
                  onPressed: () {
                    CustomerIO.registerDeviceToken(deviceToken: "device-token");
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('TRACK METRIC'),
                  onPressed: () {
                    CustomerIO.trackMetric(
                        deliveryID: "deliveryID101",
                        deviceToken: "deviceToken2011",
                        event: MetricEvent.clicked);
                  },
                ),
              ),
              const Spacer(),
              Center(
                child: ElevatedButton(
                  child: const Text('SUBSCRIBE IN-APP MESSAGE EVENTS'),
                  onPressed: () {
                    inAppMessageStreamSubscription =
                        CustomerIO.subscribeToInAppEventListener(
                            (InAppEvent event) {
                      if (kDebugMode) {
                        print("Received event: ${event.eventType.name}");
                      }
                    });
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
