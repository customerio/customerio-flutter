import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../customer_io_inapp.dart';
import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'platform_interface.dart';

/// An implementation of [CustomerIOMessagingInAppPlatform] that uses method
/// channels.
class CustomerIOMessagingInAppMethodChannel
    extends CustomerIOMessagingInAppPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io_messaging_in_app');
  final _inAppEventStreamController = StreamController<InAppEvent>.broadcast();

  @override
  Future<void> dismissMessage() {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.dismissMessage);
  }

  /// Method to subscribe to the In-App event listener.
  ///
  /// The `onEvent` function will be called whenever an In-App event occurs.
  /// Returns a [StreamSubscription] object that can be used to unsubscribe from the stream.
  @override
  StreamSubscription subscribeToInAppEventListener(
      void Function(InAppEvent) onEvent) {
    StreamSubscription subscription =
        _inAppEventStreamController.stream.listen(onEvent);
    return subscription;
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
    }
  }
}
