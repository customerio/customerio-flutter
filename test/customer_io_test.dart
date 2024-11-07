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

@GenerateMocks([TestCustomerIoPlatform])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerIO', () {
    late MockTestCustomerIoPlatform mockPlatform;

    setUp(() {
      // Reset singleton state before each test
      CustomerIO.reset();

      mockPlatform = MockTestCustomerIoPlatform();
      CustomerIOPlatform.instance = mockPlatform;
    });

    group('initialization', () {
      test('throws when accessing instance before initialization', () {
        expect(() => CustomerIO.instance, throwsStateError);
      });

      test('initialize() succeeds first time', () async {
        final config = CustomerIOConfig(cdpApiKey: '123');
        await CustomerIO.initialize(config: config);
        expect(() => CustomerIO.instance, isNot(throwsStateError));
      });

      test('subsequent initialize() calls are ignored', () async {
        final config = CustomerIOConfig(cdpApiKey: '123');

        // First initialization
        await CustomerIO.initialize(config: config);
        verify(mockPlatform.initialize(config: config)).called(1);

        // Second initialization should be ignored
        await CustomerIO.initialize(config: config);

        // Platform initialize should still only be called once
        verifyNever(mockPlatform.initialize(config: config));
      });

      test('initialize() calls platform', () async {
        final config = CustomerIOConfig(cdpApiKey: '123');
        await CustomerIO.initialize(config: config);
        verify(mockPlatform.initialize(config: config)).called(1);
      });

      test('initialize() correct arguments are passed', () async {
        final givenConfig = CustomerIOConfig(
          cdpApiKey: '123',
          migrationSiteId: '456',
          region: Region.eu,
          autoTrackDeviceAttributes: false,
        );
        await CustomerIO.initialize(config: givenConfig);
        expect(
          verify(mockPlatform.initialize(config: captureAnyNamed("config")))
              .captured
              .single,
          givenConfig,
        );
      });
    });

    group('methods requiring initialization', () {
      late CustomerIOConfig config;

      setUp(() async {
        config = CustomerIOConfig(cdpApiKey: '123');
        await CustomerIO.initialize(config: config);
      });

      test('identify() calls platform', () {
        const givenIdentifier = 'user@example.com';
        final givenAttributes = {'name': 'John Doe'};
        CustomerIO.instance.identify(
          userId: givenIdentifier,
          traits: givenAttributes,
        );

        verify(mockPlatform.identify(
          userId: givenIdentifier,
          traits: givenAttributes,
        )).called(1);
      });

      test('identify() correct arguments are passed', () {
        const givenIdentifier = 'user@example.com';
        final givenAttributes = {'name': 'John Doe'};
        CustomerIO.instance.identify(
          userId: givenIdentifier,
          traits: givenAttributes,
        );
        expect(
          verify(mockPlatform.identify(
            userId: captureAnyNamed("userId"),
            traits: captureAnyNamed("traits"),
          )).captured,
          [givenIdentifier, givenAttributes],
        );
      });

      test('clearIdentify() calls platform', () {
        CustomerIO.instance.clearIdentify();
        verify(mockPlatform.clearIdentify()).called(1);
      });

      test('track() calls platform', () {
        const name = 'itemAddedToCart';
        final attributes = {'item': 'shoes'};
        CustomerIO.instance.track(name: name, attributes: attributes);
        verify(mockPlatform.track(name: name, attributes: attributes))
            .called(1);
      });

      test('track() correct arguments are passed', () {
        const name = 'itemAddedToCart';
        final givenAttributes = {'name': 'John Doe'};
        CustomerIO.instance.track(name: name, attributes: givenAttributes);
        expect(
          verify(mockPlatform.track(
            name: captureAnyNamed("name"),
            attributes: captureAnyNamed("attributes"),
          )).captured,
          [name, givenAttributes],
        );
      });

      test('trackMetric() calls platform', () {
        const deliveryID = '123';
        const deviceToken = 'abc';
        const event = MetricEvent.opened;
        CustomerIO.instance.trackMetric(
          deliveryID: deliveryID,
          deviceToken: deviceToken,
          event: event,
        );
        verify(mockPlatform.trackMetric(
          deliveryID: deliveryID,
          deviceToken: deviceToken,
          event: event,
        )).called(1);
      });

      // ... rest of the existing tests, but moved inside this group ...

      test('setProfileAttributes() correct arguments are passed', () {
        final givenAttributes = {'age': 10};
        CustomerIO.instance.setProfileAttributes(attributes: givenAttributes);
        expect(
          verify(mockPlatform.setProfileAttributes(
            traits: captureAnyNamed("traits"),
          )).captured.first,
          givenAttributes,
        );
      });
    });
  });
}
