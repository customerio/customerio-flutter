import 'package:customer_io/customer_io.dart';
import 'package:customer_io/liveActivities/method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the Live Activities method channel invokes the correct native
/// method names with the expected argument shapes.
void main() {
  const MethodChannel channel = MethodChannel('customer_io_live_activities');
  final Map<String, dynamic> methodInvocations = {};

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    methodInvocations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      methodInvocations[methodCall.method] = methodCall.arguments;
      switch (methodCall.method) {
        case 'start':
        case 'startCustom':
          return 'activity-123';
        case 'update':
        case 'end':
          return null;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start() sends segments payload and returns the activity id', () async {
    final platform = CustomerIOLiveActivitiesMethodChannel();

    final id = await platform.start(
      const LiveActivityPayload.segments(
        header: 'Order',
        status: 'Preparing',
        substatus: 'In kitchen',
        segmentsTotal: 4,
        segmentsComplete: 1,
        trailingText: 'ETA 20 min',
      ),
    );

    expect(id, 'activity-123');
    expect(methodInvocations.containsKey('start'), isTrue);
    final args = methodInvocations['start'] as Map;
    final payload = args['payload'] as Map;
    expect(payload['type'], 'io.customer.livenotifications.segments');
    expect(payload['header'], 'Order');
    expect(payload['status'], 'Preparing');
    expect(payload['substatus'], 'In kitchen');
    expect(payload['segmentsTotal'], 4);
    expect(payload['segmentsComplete'], 1);
    expect(payload['trailingText'], 'ETA 20 min');
  });

  test('start() sends countdownTimer payload with epoch-seconds endTime',
      () async {
    final platform = CustomerIOLiveActivitiesMethodChannel();

    await platform.start(
      const LiveActivityPayload.countdownTimer(
        header: 'Sale',
        title: 'Ends soon',
        statusMessage: 'Hurry',
        endTime: 1893456000,
      ),
    );

    final args = methodInvocations['start'] as Map;
    final payload = args['payload'] as Map;
    expect(payload['type'], 'io.customer.livenotifications.countdowntimer');
    expect(payload['header'], 'Sale');
    expect(payload['title'], 'Ends soon');
    expect(payload['statusMessage'], 'Hurry');
    expect(payload['endTime'], 1893456000);
  });

  test('update() sends activityId and full payload', () async {
    final platform = CustomerIOLiveActivitiesMethodChannel();

    await platform.update(
      'activity-123',
      const LiveActivityPayload.segments(
        header: 'Order',
        status: 'Out for delivery',
        segmentsTotal: 4,
        segmentsComplete: 3,
      ),
    );

    final args = methodInvocations['update'] as Map;
    expect(args['activityId'], 'activity-123');
    final payload = args['payload'] as Map;
    expect(payload['type'], 'io.customer.livenotifications.segments');
    expect(payload['status'], 'Out for delivery');
    expect(payload['segmentsComplete'], 3);
    expect(payload['substatus'], isNull);
  });

  test('end() sends the activityId', () async {
    final platform = CustomerIOLiveActivitiesMethodChannel();

    await platform.end('activity-123');

    final args = methodInvocations['end'] as Map;
    expect(args['activityId'], 'activity-123');
  });

  test('startCustom() sends activityType and data, returns id', () async {
    final platform = CustomerIOLiveActivitiesMethodChannel();

    final id = await platform.startCustom('rideStatus', {'driver': 'Alex'});

    expect(id, 'activity-123');
    final args = methodInvocations['startCustom'] as Map;
    expect(args['activityType'], 'rideStatus');
    expect((args['data'] as Map)['driver'], 'Alex');
  });

  group('resilience', () {
    /// A newer native SDK can reject a template this wrapper build doesn't know
    /// about. That must surface as a catchable error, never an uncaught crash.
    test('start() propagates an unsupported-type native error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'live_activity_type_unsupported',
          message: 'Unsupported Live Activity template: io.example.unknown',
        );
      });
      final platform = CustomerIOLiveActivitiesMethodChannel();

      await expectLater(
        platform.start(
          const LiveActivityPayload.segments(
            header: 'Order #123',
            status: 'Preparing',
            segmentsTotal: 4,
            segmentsComplete: 1,
          ),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'live_activity_type_unsupported',
          ),
        ),
      );
    });

    /// The module may not be registered (type not enabled in the SDK config).
    /// The native side replies with an error rather than crashing.
    test('start() propagates a type-not-registered native error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'live_activity_type_not_registered');
      });
      final platform = CustomerIOLiveActivitiesMethodChannel();

      await expectLater(
        platform.start(
          const LiveActivityPayload.countdownTimer(
            header: 'Sale',
            title: 'Ends soon',
          ),
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    /// A missing native side (module not built in) is reported as a clear
    /// StateError instead of leaking MissingPluginException.
    test('start() reports a disabled module as a StateError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw MissingPluginException();
      });
      final platform = CustomerIOLiveActivitiesMethodChannel();

      await expectLater(
        platform.start(
          const LiveActivityPayload.segments(
            header: 'Order #123',
            status: 'Preparing',
            segmentsTotal: 4,
            segmentsComplete: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    /// A null id means nothing was started. Failing here surfaces the cause; returning '' would hand
    /// back an id that only fails later, on an update or end that silently matches nothing.
    test('start() throws when native returns a null id', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
      final platform = CustomerIOLiveActivitiesMethodChannel();

      expect(
        () => platform.start(
          const LiveActivityPayload.segments(
            header: 'Order #123',
            status: 'Preparing',
            segmentsTotal: 4,
            segmentsComplete: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
