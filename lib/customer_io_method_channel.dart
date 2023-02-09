import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'customer_io_config.dart';
import 'customer_io_const.dart';
import 'customer_io_inapp.dart';
import 'customer_io_platform_interface.dart';
import 'customer_io_plugin_version.dart';

/// An implementation of [CustomerIOPlatform] that uses method channels.
class CustomerIOMethodChannel extends CustomerIOPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io');

  final _inAppEventStreamController = StreamController<InAppEvent>.broadcast();

  CustomerIOMethodChannel() {
    methodChannel.setMethodCallHandler(_onMethodCall);
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

  /// To initialize the plugin
  @override
  Future<void> initialize({
    required CustomerIOConfig config,
  }) async {
    try {
      config.version = version;
      if (!config.enableInApp && config.organizationId.isNotEmpty) {
        config.enableInApp = true;
      }
      await methodChannel.invokeMethod(MethodConsts.initialize, config.toMap());
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// Identify a person using a unique identifier, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  @override
  void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.identifier: identifier,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.identify, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  @override
  void track(
      {required String name,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.eventName: name,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.track, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// Track screen events to record the screens a user visits
  @override
  void screen(
      {required String name,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.eventName: name,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.screen, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// Call this function to stop identifying a person.
  @override
  void clearIdentify() {
    try {
      methodChannel.invokeMethod(MethodConsts.clearIdentify);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  @override
  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    try {
      final payload = {TrackingConsts.attributes: attributes};
      methodChannel.invokeMethod(MethodConsts.setProfileAttributes, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  @override
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    try {
      final payload = {TrackingConsts.attributes: attributes};
      methodChannel.invokeMethod(MethodConsts.setDeviceAttributes, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }
}
