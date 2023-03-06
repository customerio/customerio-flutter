import 'dart:async';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:customer_io/customer_io_inapp.dart';
import 'package:customer_io/customer_io_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'customer_io_test.mocks.dart';

///The TestCustomerIoPlatform class is a mock implementation of the CustomerIOPlatform interface.
/// It provides mock implementations of the methods defined in the CustomerIOPlatform interface,
/// which are intended to be overridden in tests. The purpose of this class is to simulate the behavior
/// of the actual platform implementation, so that tests can run without making actual calls to the platform,
class TestCustomerIoPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements CustomerIOPlatform {
  @override
  Future<void> initialize({required CustomerIOConfig config}) {
    return Future.value();
  }
}

// The following test suite make sures when any CustomerIO class method is called,
// the corresponding platform method are called.
@GenerateMocks([TestCustomerIoPlatform])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerIO', () {
    late MockTestCustomerIoPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockTestCustomerIoPlatform();
      CustomerIOPlatform.instance = mockPlatform;
    });

    test('initialize() calls platform', () async {
      final config = CustomerIOConfig(siteId: '123', apiKey: '456');
      await CustomerIO.initialize(config: config);
      verify(mockPlatform.initialize(config: config)).called(1);
    });

    test('identify() calls platform', () {
      const identifier = 'user@example.com';
      final attributes = {'name': 'John Doe'};
      CustomerIO.identify(identifier: identifier, attributes: attributes);
      verify(mockPlatform.identify(identifier: identifier, attributes: attributes)).called(1);
    });

    test('clearIdentify() calls platform', () {
      CustomerIO.clearIdentify();
      verify(mockPlatform.clearIdentify()).called(1);
    });

    test('track() calls platform', () {
      const name = 'itemAddedToCart';
      final attributes = {'item': 'shoes'};
      CustomerIO.track(name: name, attributes: attributes);
      verify(mockPlatform.track(name: name, attributes: attributes)).called(1);
    });

    test('trackMetric() calls platform', () {
      const deliveryID = '123';
      const deviceToken = 'abc';
      const event = MetricEvent.opened;
      CustomerIO.trackMetric(deliveryID: deliveryID, deviceToken: deviceToken, event: event);
      verify(mockPlatform.trackMetric(deliveryID: deliveryID, deviceToken: deviceToken, event: event)).called(1);
    });

    test('registerDeviceToken() calls platform', () {
      const deviceToken = 'abc';
      CustomerIO.registerDeviceToken(deviceToken: deviceToken);
      verify(mockPlatform.registerDeviceToken(deviceToken: deviceToken)).called(1);
    });

    test('screen() calls platform', () {
      const name = 'home';
      final attributes = {'user': 'John Doe'};
      CustomerIO.screen(name: name, attributes: attributes);
      verify(mockPlatform.screen(name: name, attributes: attributes)).called(1);
    });

    test('setDeviceAttributes() calls platform', () {
      final attributes = {'region': 'US'};
      CustomerIO.setDeviceAttributes(attributes: attributes);
      verify(mockPlatform.setDeviceAttributes(attributes: attributes)).called(1);
    });

    test('setProfileAttributes() calls platform', () {
      final attributes = {'age': 10};
      CustomerIO.setProfileAttributes(attributes: attributes);
      verify(mockPlatform.setProfileAttributes(attributes: attributes)).called(1);
    });
  });
}