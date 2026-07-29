import 'package:customer_io/messaging_in_app.dart';
import 'package:customer_io/messaging_in_app/method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simple recording listener used to assert dispatched inbox events.
class _RecordingInboxEventListener implements InboxEventListener {
  final List<String> events = [];
  InboxMessage? lastMessage;
  String? lastActionName;
  String? lastActionValue;

  @override
  void messageActionTaken(
      InboxMessage message, String actionName, String actionValue) {
    events.add('actionTaken');
    lastMessage = message;
    lastActionName = actionName;
    lastActionValue = actionValue;
  }

  @override
  void messageShown(InboxMessage message) {
    events.add('shown');
    lastMessage = message;
  }

  @override
  void messageOpened(InboxMessage message) {
    events.add('opened');
    lastMessage = message;
  }

  @override
  void messageDismissed(InboxMessage message) {
    events.add('dismissed');
    lastMessage = message;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'customer_io_messaging_in_app';

  late CustomerIOMessagingInAppMethodChannel platform;
  late List<MethodCall> nativeCalls;

  // Serialized InboxMessage matching InboxMessage.fromMap / native toMap shape.
  final messageMap = <String, dynamic>{
    'queueId': 'queue-123',
    'deliveryId': 'delivery-456',
    'expiry': 1710000000000,
    'sentAt': 1700000000000,
    'topics': ['promo', 'news'],
    'type': 'inbox',
    'opened': false,
    'priority': 1,
    'properties': {'foo': 'bar'},
  };

  Future<void> simulateNativeCall(String method, Object? arguments) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (data) {},
    );
  }

  setUp(() {
    nativeCalls = [];
    platform = CustomerIOMessagingInAppMethodChannel();

    // Capture outgoing (Dart -> native) method calls.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
      nativeCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
  });

  test('setInboxEventListener registers with native', () {
    platform.setInboxEventListener(_RecordingInboxEventListener());

    expect(
      nativeCalls.map((c) => c.method),
      contains('registerInboxEventListener'),
    );
  });

  test('inboxMessageActionTaken dispatches a parsed message + action', () async {
    final listener = _RecordingInboxEventListener();
    platform.setInboxEventListener(listener);

    await simulateNativeCall('inboxMessageActionTaken', {
      'message': messageMap,
      'actionName': 'messageAction',
      'actionValue': 'https://example.com',
    });

    expect(listener.events, ['actionTaken']);
    expect(listener.lastMessage?.queueId, 'queue-123');
    expect(listener.lastMessage?.deliveryId, 'delivery-456');
    expect(listener.lastMessage?.topics, ['promo', 'news']);
    expect(listener.lastActionName, 'messageAction');
    expect(listener.lastActionValue, 'https://example.com');
  });

  test('observational inbox callbacks dispatch to the listener', () async {
    final listener = _RecordingInboxEventListener();
    platform.setInboxEventListener(listener);

    await simulateNativeCall('inboxMessageShown', {'message': messageMap});
    await simulateNativeCall('inboxMessageOpened', {'message': messageMap});
    await simulateNativeCall('inboxMessageDismissed', {'message': messageMap});

    expect(listener.events, ['shown', 'opened', 'dismissed']);
    expect(listener.lastMessage?.queueId, 'queue-123');
  });

  test(
      'native register failure tears down the Dart subscription instead of leaving it attached',
      () async {
    // Native rejects the registration. Dart must not stay subscribed: the app would otherwise
    // believe a listener is live while native never installed the forwarder.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
      nativeCalls.add(call);
      if (call.method == 'registerInboxEventListener') {
        throw PlatformException(
          code: 'INBOX_NOT_AVAILABLE',
          message: 'In-app messaging module is not available.',
        );
      }
      return null;
    });

    final listener = _RecordingInboxEventListener();
    platform.setInboxEventListener(listener);

    // Let the rejected invokeMethod future settle so the error handler can run.
    await pumpEventQueue();

    await simulateNativeCall('inboxMessageShown', {'message': messageMap});
    expect(listener.events, isEmpty);
  });

  test('setInboxEventListener(null) unregisters and stops dispatching',
      () async {
    final listener = _RecordingInboxEventListener();
    platform.setInboxEventListener(listener);
    nativeCalls.clear();

    platform.setInboxEventListener(null);

    expect(
      nativeCalls.map((c) => c.method),
      contains('unregisterInboxEventListener'),
    );

    // Events arriving after unregister must not reach the old listener.
    await simulateNativeCall('inboxMessageShown', {'message': messageMap});
    expect(listener.events, isEmpty);
  });
}
