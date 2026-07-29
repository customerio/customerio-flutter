import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../customer_io_inapp.dart';
import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'inbox_event_listener.dart';
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
  final _inboxEventStreamController =
      StreamController<_InboxEvent>.broadcast();

  /// Active subscription that dispatches inbox events to the registered
  /// [InboxEventListener]. Null when no listener is registered.
  StreamSubscription<_InboxEvent>? _inboxEventSubscription;

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

  /// Registers (or clears) the global inbox event listener.
  ///
  /// Passing a non-null [listener] wires a subscription that dispatches inbox
  /// events to it and tells the native SDK to start forwarding events (the
  /// native forwarder reports actions as host-handled, so the SDK suppresses
  /// its default navigation while a listener is registered). Passing `null`
  /// cancels the subscription and tells the native SDK to restore its default
  /// behavior.
  @override
  void setInboxEventListener(InboxEventListener? listener) {
    // Always tear down any existing subscription first.
    _inboxEventSubscription?.cancel();
    _inboxEventSubscription = null;

    if (listener == null) {
      methodChannel
          .invokeNativeMethodVoid(NativeMethods.unregisterInboxEventListener);
      return;
    }

    _inboxEventSubscription =
        _inboxEventStreamController.stream.listen((event) {
      switch (event.type) {
        case _InboxEventType.messageActionTaken:
          listener.messageActionTaken(
              event.message, event.actionName ?? '', event.actionValue ?? '');
          break;
        case _InboxEventType.messageShown:
          listener.messageShown(event.message);
          break;
        case _InboxEventType.messageOpened:
          listener.messageOpened(event.message);
          break;
        case _InboxEventType.messageDismissed:
          listener.messageDismissed(event.message);
          break;
      }
    });

    // Registered through the raw channel rather than `invokeNativeMethodVoid`, which swallows
    // PlatformException and returns null for both success and failure — indistinguishable. A failed
    // registration would otherwise leave the Dart subscription above attached while native never
    // installed the forwarder, so the app believes a listener is live and inbox callbacks never
    // arrive. On failure the Dart side is undone so the two stay in agreement.
    methodChannel
        .invokeMethod<void>(NativeMethods.registerInboxEventListener)
        .catchError((Object error) {
      if (kDebugMode) {
        print('Failed to register inbox event listener natively: $error');
      }
      _inboxEventSubscription?.cancel();
      _inboxEventSubscription = null;
    });
  }

  // Inbox methods

  @override
  Future<List<InboxMessage>> getMessages({String? topic}) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      NativeMethods.getInboxMessages,
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
  Stream<List<InboxMessage>> messages({String? topic}) {
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
      case NativeMethods.inboxMessageActionTaken:
        _inboxEventStreamController.add(_InboxEvent(
          type: _InboxEventType.messageActionTaken,
          message: _inboxMessageFromArgs(arguments),
          actionName: arguments[NativeMethodParams.actionName] as String?,
          actionValue: arguments['actionValue'] as String?,
        ));
        break;
      case NativeMethods.inboxMessageShown:
        _inboxEventStreamController.add(_InboxEvent(
          type: _InboxEventType.messageShown,
          message: _inboxMessageFromArgs(arguments),
        ));
        break;
      case NativeMethods.inboxMessageOpened:
        _inboxEventStreamController.add(_InboxEvent(
          type: _InboxEventType.messageOpened,
          message: _inboxMessageFromArgs(arguments),
        ));
        break;
      case NativeMethods.inboxMessageDismissed:
        _inboxEventStreamController.add(_InboxEvent(
          type: _InboxEventType.messageDismissed,
          message: _inboxMessageFromArgs(arguments),
        ));
        break;
    }
  }

  /// Parses the `message` map that native sends alongside inbox events into an
  /// [InboxMessage], using the same serialization shape as `inboxMessagesChanged`.
  InboxMessage _inboxMessageFromArgs(Map<String, dynamic> arguments) {
    final messageMap = (arguments[NativeMethodParams.message]
            as Map<Object?, Object?>)
        .cast<String, dynamic>();
    return InboxMessage.fromMap(messageMap);
  }
}

/// Type of inbox event forwarded from native.
enum _InboxEventType {
  messageActionTaken,
  messageShown,
  messageOpened,
  messageDismissed,
}

/// Internal carrier for an inbox event flowing through the broadcast stream to
/// the registered [InboxEventListener].
class _InboxEvent {
  final _InboxEventType type;
  final InboxMessage message;
  final String? actionName;
  final String? actionValue;

  _InboxEvent({
    required this.type,
    required this.message,
    this.actionName,
    this.actionValue,
  });
}
