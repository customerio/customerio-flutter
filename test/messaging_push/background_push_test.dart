import 'dart:async';
import 'dart:ui';

import 'package:customer_io/customer_io.dart';
import 'package:customer_io/messaging_push/method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final List<CustomerIOBackgroundPush> handledPushes = [];

@pragma('vm:entry-point')
void recordingHandler(CustomerIOBackgroundPush push) => handledPushes.add(push);

const pushArguments = {
  'deliveryId': 'dlv_1',
  'deliveryToken': 'tok_1',
  'data': {'account': 'refresh'},
};

void expectRecordedPush() {
  final push = handledPushes.single;
  expect(push.deliveryId, 'dlv_1');
  expect(push.deliveryToken, 'tok_1');
  expect(push.data, {'account': 'refresh'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('customer_io_messaging_push');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> nativeCalls = [];

  setUp(() {
    handledPushes.clear();
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  /// Sends a push the way native does. Completes with null when no Dart
  /// handler is set.
  Future<ByteData?> sendFromNative() {
    final reply = Completer<ByteData?>();
    messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        const MethodCall('onBackgroundPushReceived', pushArguments),
      ),
      reply.complete,
    );
    return reply.future;
  }

  test('registering sends both callback handles to native', () async {
    await CustomerIO.pushMessaging.setBackgroundPushHandler(recordingHandler);

    final call = nativeCalls.single;
    expect(call.method, 'registerBackgroundPushHandler');
    expect(
      call.arguments['handlerHandle'],
      PluginUtilities.getCallbackHandle(recordingHandler)!.toRawHandle(),
    );
    expect(call.arguments['dispatcherHandle'], isA<int>());
  });

  test('a closure is rejected, since it has no callback handle', () async {
    await expectLater(
      CustomerIOMessagingPushMethodChannel().setBackgroundPushHandler(
        (push) {},
      ),
      throwsArgumentError,
    );
    expect(nativeCalls, isEmpty);
  });

  test('a push from native runs the handler on the main isolate', () async {
    await CustomerIOMessagingPushMethodChannel().setBackgroundPushHandler(
      recordingHandler,
    );

    await sendFromNative();

    expectRecordedPush();
  });

  test('null clears the handler in Dart and native', () async {
    final platform = CustomerIOMessagingPushMethodChannel();
    await platform.setBackgroundPushHandler(recordingHandler);

    await platform.setBackgroundPushHandler(null);

    expect(nativeCalls.last.method, 'clearBackgroundPushHandler');
    expect(await sendFromNative(), isNull);
    expect(handledPushes, isEmpty);
  });

  test('the background isolate runs the handler found by its handle', () async {
    await handleBackgroundIsolateCall(
      MethodCall('onBackgroundPushReceived', {
        ...pushArguments,
        'handlerHandle': PluginUtilities.getCallbackHandle(
          recordingHandler,
        )!.toRawHandle(),
      }),
    );

    expectRecordedPush();
  });
}
