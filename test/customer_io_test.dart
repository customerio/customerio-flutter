import 'package:customer_io/customer_io.dart';
import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
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

// The following test suite makes sure when any CustomerIO class method is called,
// the correct corresponding platform methods are called and with the correct arguments.
@GenerateMocks([TestCustomerIoPlatform])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerIO', () {
    late MockTestCustomerIoPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockTestCustomerIoPlatform();
      CustomerIOPlatform.instance = mockPlatform;
    });

    // initialize
    test('initialize() calls platform', () async {
      final config = CustomerIOConfig(siteId: '123', apiKey: '456');
      await CustomerIO.instance.initialize(config: config);

      verify(mockPlatform.initialize(config: config)).called(1);
    });

    test('initialize() correct arguments are passed', () async {
      final givenConfig = CustomerIOConfig(
          siteId: '123',
          apiKey: '456',
          region: Region.eu,
          autoTrackPushEvents: false);
      await CustomerIO.instance.initialize(config: givenConfig);
      expect(
          verify(mockPlatform.initialize(config: captureAnyNamed("config")))
              .captured
              .single,
          givenConfig);
    });

    // identify
    test('identify() calls platform', () {
      const givenIdentifier = 'user@example.com';
      final givenAttributes = {'name': 'John Doe'};
      CustomerIO.instance
          .identify(identifier: givenIdentifier, attributes: givenAttributes);

      verify(mockPlatform.identify(
              identifier: givenIdentifier, attributes: givenAttributes))
          .called(1);
    });

    test('identify() correct arguments are passed', () {
      const givenIdentifier = 'user@example.com';
      final givenAttributes = {'name': 'John Doe'};
      CustomerIO.instance
          .identify(identifier: givenIdentifier, attributes: givenAttributes);
      expect(
          verify(mockPlatform.identify(
                  identifier: captureAnyNamed("identifier"),
                  attributes: captureAnyNamed("attributes")))
              .captured,
          [givenIdentifier, givenAttributes]);
    });

    // clearIdentify
    test('clearIdentify() calls platform', () {
      CustomerIO.instance.clearIdentify();
      verify(mockPlatform.clearIdentify()).called(1);
    });

    // track
    test('track() calls platform', () {
      const name = 'itemAddedToCart';
      final attributes = {'item': 'shoes'};
      CustomerIO.instance.track(name: name, attributes: attributes);
      verify(mockPlatform.track(name: name, attributes: attributes)).called(1);
    });

    test('track() correct arguments are passed', () {
      const name = 'itemAddedToCart';
      final givenAttributes = {'name': 'John Doe'};
      CustomerIO.instance.track(name: name, attributes: givenAttributes);
      expect(
          verify(mockPlatform.track(
                  name: captureAnyNamed("name"),
                  attributes: captureAnyNamed("attributes")))
              .captured,
          [name, givenAttributes]);
    });

    // trackMetric
    test('trackMetric() calls platform', () {
      const deliveryID = '123';
      const deviceToken = 'abc';
      const event = MetricEvent.opened;
      CustomerIO.instance.trackMetric(
          deliveryID: deliveryID, deviceToken: deviceToken, event: event);
      verify(mockPlatform.trackMetric(
              deliveryID: deliveryID, deviceToken: deviceToken, event: event))
          .called(1);
    });

    test('trackMetric() correct arguments are passed', () {
      const deliveryID = '123';
      const deviceToken = 'abc';
      const event = MetricEvent.opened;
      CustomerIO.instance.trackMetric(
          deliveryID: deliveryID, deviceToken: deviceToken, event: event);
      expect(
          verify(mockPlatform.trackMetric(
                  deliveryID: captureAnyNamed("deliveryID"),
                  deviceToken: captureAnyNamed("deviceToken"),
                  event: captureAnyNamed("event")))
              .captured,
          [deliveryID, deviceToken, event]);
    });

    // registerDeviceToken
    test('registerDeviceToken() calls platform', () {
      const deviceToken = 'token';
      CustomerIO.instance.registerDeviceToken(deviceToken: deviceToken);
      verify(mockPlatform.registerDeviceToken(deviceToken: deviceToken))
          .called(1);
    });

    test('registerDeviceToken() correct arguments are passed', () {
      const deviceToken = 'token';
      CustomerIO.instance.registerDeviceToken(deviceToken: deviceToken);
      expect(
          verify(mockPlatform.registerDeviceToken(
                  deviceToken: captureAnyNamed("deviceToken")))
              .captured
              .first,
          deviceToken);
    });

    // screen
    test('screen() calls platform', () {
      const name = 'home';
      final givenAttributes = {'user': 'John Doe'};
      CustomerIO.instance.screen(name: name, attributes: givenAttributes);
      verify(mockPlatform.screen(name: name, attributes: givenAttributes))
          .called(1);
    });

    test('screen() correct arguments are passed', () {
      const name = 'itemAddedToCart';
      final givenAttributes = {'name': 'John Doe'};
      CustomerIO.instance.screen(name: name, attributes: givenAttributes);
      expect(
          verify(mockPlatform.screen(
                  name: captureAnyNamed("name"),
                  attributes: captureAnyNamed("attributes")))
              .captured,
          [name, givenAttributes]);
    });

    // setDeviceAttributes
    test('setDeviceAttributes() calls platform', () {
      final givenAttributes = {'area': 'US'};
      CustomerIO.instance.setDeviceAttributes(attributes: givenAttributes);
      verify(mockPlatform.setDeviceAttributes(attributes: givenAttributes))
          .called(1);
    });

    test('setDeviceAttributes() correct arguments are passed', () {
      final givenAttributes = {'area': 'US'};
      CustomerIO.instance.setDeviceAttributes(attributes: givenAttributes);
      expect(
          verify(mockPlatform.setDeviceAttributes(
                  attributes: captureAnyNamed("attributes")))
              .captured
              .first,
          givenAttributes);
    });

    // setProfileAttributes
    test('setProfileAttributes() calls platform', () {
      final givenAttributes = {'age': 10};
      CustomerIO.instance.setProfileAttributes(attributes: givenAttributes);
      verify(mockPlatform.setProfileAttributes(attributes: givenAttributes))
          .called(1);
    });

    test('setProfileAttributes() correct arguments are passed', () {
      final givenAttributes = {'age': 10};
      CustomerIO.instance.setProfileAttributes(attributes: givenAttributes);
      expect(
          verify(mockPlatform.setProfileAttributes(
                  attributes: captureAnyNamed("attributes")))
              .captured
              .first,
          givenAttributes);
    });
  });

  test('Singleton instance should be initialized once', () {
    var firstInstance = CustomerIO.instance;
    var secondInstance = CustomerIO.instance;
    expect(firstInstance, secondInstance);
  });
}
