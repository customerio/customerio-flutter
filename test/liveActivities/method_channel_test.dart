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
    expect(payload['type'], 'segments');
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
    expect(payload['type'], 'countdownTimer');
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
    expect(payload['type'], 'segments');
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
}
