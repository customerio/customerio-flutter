import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../customer_io_inapp.dart';
import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'inbox_message.dart';
import 'platform_interface.dart';

/// An implementation of [CustomerIOMessagingInAppPlatform] that uses method
/// channels.
class CustomerIOMessagingInAppMethodChannel
    extends CustomerIOMessagingInAppPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io_messaging_in_app');
  final _inAppEventStreamController = StreamController<InAppEvent>.broadcast();
  final _inboxMessagesStreamController =
      StreamController<List<InboxMessage>>.broadcast();

  @override
  void dismissMessage() {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.dismissMessage);
  }

  /// Method to subscribe to the In-App event listener.
  ///
  /// The `onEvent` function will be called whenever an In-App event occurs.
  /// Returns a [StreamSubscription] object that can be used to unsubscribe from the stream.
  @override
  StreamSubscription subscribeToEventsListener(
      void Function(InAppEvent) onEvent) {
    StreamSubscription subscription =
        _inAppEventStreamController.stream.listen(onEvent);
    return subscription;
  }

  // Inbox methods

  @override
  Future<List<InboxMessage>> fetchInboxMessages({String? topic}) async {
    // Native fetchInboxMessages automatically sets up the listener

    final result = await methodChannel.invokeMethod<List<dynamic>>(
      NativeMethods.fetchInboxMessages,
      topic != null ? {NativeMethodParams.topic: topic} : null,
    );

    if (result == null) {
      return [];
    }

    return result
        .map((item) => InboxMessage.fromMap(
            (item as Map<Object?, Object?>).cast<String, dynamic>()))
        .toList();
  }

  @override
  Stream<List<InboxMessage>> inboxMessagesStream({String? topic}) {
    // Set up listener for real-time updates (native side prevents duplicates)
    methodChannel
        .invokeNativeMethodVoid(NativeMethods.subscribeToInboxMessages);

    // Filter stream by topic if provided
    if (topic != null) {
      return _inboxMessagesStreamController.stream.map((messages) {
        return messages.where((message) {
          return message.topics
              .any((t) => t.toLowerCase() == topic.toLowerCase());
        }).toList();
      });
    }
    return _inboxMessagesStreamController.stream;
  }

  @override
  void markInboxMessageOpened({required InboxMessage message}) {
    methodChannel.invokeNativeMethodVoid(
      NativeMethods.markInboxMessageOpened,
      {NativeMethodParams.message: message.toMap()},
    );
  }

  @override
  void markInboxMessageUnopened({required InboxMessage message}) {
    methodChannel.invokeNativeMethodVoid(
      NativeMethods.markInboxMessageUnopened,
      {NativeMethodParams.message: message.toMap()},
    );
  }

  @override
  void markInboxMessageDeleted({required InboxMessage message}) {
    methodChannel.invokeNativeMethodVoid(
      NativeMethods.markInboxMessageDeleted,
      {NativeMethodParams.message: message.toMap()},
    );
  }

  @override
  void trackInboxMessageClicked(
      {required InboxMessage message, String? actionName}) {
    methodChannel.invokeNativeMethodVoid(
      NativeMethods.trackInboxMessageClicked,
      {
        NativeMethodParams.message: message.toMap(),
        if (actionName != null) NativeMethodParams.actionName: actionName,
      },
    );
  }

  CustomerIOMessagingInAppMethodChannel() {
    methodChannel.setMethodCallHandler(_onMethodCall);
  }

  /// Method call handler to handle events from native bindings
  Future<dynamic> _onMethodCall(MethodCall call) async {
    /// Cast the arguments to a map of strings to dynamic values.
    final arguments =
        (call.arguments as Map<Object?, Object?>).cast<String, dynamic>();

    switch (call.method) {
      case "messageShown":
        _inAppEventStreamController
            .add(InAppEvent.fromMap(EventType.messageShown, arguments));
        break;
      case "messageDismissed":
        _inAppEventStreamController
            .add(InAppEvent.fromMap(EventType.messageDismissed, arguments));
        break;
      case "errorWithMessage":
        _inAppEventStreamController
            .add(InAppEvent.fromMap(EventType.errorWithMessage, arguments));
        break;
      case "messageActionTaken":
        _inAppEventStreamController
            .add(InAppEvent.fromMap(EventType.messageActionTaken, arguments));
        break;
      case "inboxMessagesChanged":
        final messagesList = (arguments[NativeMethodParams.messages]
                    as List<dynamic>?)
                ?.map((item) => InboxMessage.fromMap(
                    (item as Map<Object?, Object?>).cast<String, dynamic>()))
                .toList() ??
            [];
        _inboxMessagesStreamController.add(messagesList);
        break;
    }
  }
}
