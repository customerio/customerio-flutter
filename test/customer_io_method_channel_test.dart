import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// This is more of test of what our Native platform is expecting.
void main() {
  const MethodChannel channel = MethodChannel('customer_io');
  final Map<String, dynamic> methodInvocations = {};

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      methodInvocations[methodCall.method] = methodCall.arguments;
      switch (methodCall.method) {
        case 'initialize':
          return Future
              .value(); // Simulate a successful response from the platform.
        case 'identify':
        case 'track':
        case 'trackMetric':
        case 'screen':
        case 'registerDeviceToken':
        case 'clearIdentify':
        case 'setProfileAttributes':
        case 'setDeviceAttributes':
          return Future(() => null);
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectMethodInvocationArguments(
      String methodKey, Map<String, dynamic> arguments) {
    expect(methodInvocations.containsKey(methodKey), true,
        reason: 'method `$methodKey` was called');
    arguments.forEach((key, value) {
      expect(methodInvocations[methodKey][key], value,
          reason: 'method arg $key matches');
    });
  }

  test('initialize() should call platform method with correct arguments',
      () async {
    final customerIO = CustomerIOMethodChannel();
    final config = CustomerIOConfig(cdpApiKey: 'cdp_api_key');
    await customerIO.initialize(config: config);

    expectMethodInvocationArguments(
        'initialize', {'cdpApiKey': config.cdpApiKey});
  });

  test('identify() should call platform method with correct arguments',
      () async {
    final Map<String, dynamic> args = {
      'identifier': 'Customer 1',
      'attributes': {'email': 'customer@email.com'}
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.identify(
        identifier: args['identifier'] as String,
        attributes: args['attributes']);

    expectMethodInvocationArguments('identify', args);
  });

  test('track() should call platform method with correct arguments', () async {
    final Map<String, dynamic> args = {
      'eventName': 'test_event',
      'attributes': {'eventData': 2}
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.track(name: args['eventName'], properties: args['attributes']);

    expectMethodInvocationArguments('track', args);
  });

  test('trackMetric() should call platform method with correct arguments',
      () async {
    final Map<String, dynamic> args = {
      'deliveryId': '123',
      'deliveryToken': 'asdf',
      'metricEvent': 'clicked'
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.trackMetric(
        deliveryID: args['deliveryId'],
        deviceToken: args['deliveryToken'],
        event: MetricEvent.values.byName(args['metricEvent']));

    expectMethodInvocationArguments('trackMetric', args);
  });

  test('screen() should call platform method with correct arguments', () async {
    final Map<String, dynamic> args = {
      'eventName': 'screen_event',
      'attributes': {'screenName': '你好'}
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.screen(name: args['eventName'], attributes: args['attributes']);

    expectMethodInvocationArguments('screen', args);
  });

  test(
      'registerDeviceToken() should call platform method with correct arguments',
      () async {
    final Map<String, String> args = {'token': 'asdf'};

    final customerIO = CustomerIOMethodChannel();
    customerIO.registerDeviceToken(deviceToken: args['token'] as String);

    expectMethodInvocationArguments('registerDeviceToken', args);
  });

  test('clearIdentify() should call platform method with correct arguments',
      () async {
    final Map<String, String> args = {};

    final customerIO = CustomerIOMethodChannel();
    customerIO.clearIdentify();

    expectMethodInvocationArguments('clearIdentify', args);
  });

  test(
      'setProfileAttributes() should call platform method with correct arguments',
      () async {
    final Map<String, dynamic> args = {
      'attributes': {'age': 1}
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.setProfileAttributes(attributes: args['attributes']);

    expectMethodInvocationArguments('setProfileAttributes', args);
  });

  test(
      'setDeviceAttributes() should call platform method with correct arguments',
      () async {
    final Map<String, dynamic> args = {
      'attributes': {'os': 'Android'}
    };

    final customerIO = CustomerIOMethodChannel();
    customerIO.setDeviceAttributes(attributes: args['attributes']);

    expectMethodInvocationArguments('setDeviceAttributes', args);
  });
}
