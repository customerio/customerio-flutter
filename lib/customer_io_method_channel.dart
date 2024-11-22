import 'dart:async';

import 'package:customer_io/customer_io_enums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'customer_io_config.dart';
import 'customer_io_const.dart';
import 'customer_io_platform_interface.dart';

/// An implementation of [CustomerIOPlatform] that uses method channels.
class CustomerIOMethodChannel extends CustomerIOPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io');

  /// To initialize the plugin
  @override
  Future<void> initialize({
    required CustomerIOConfig config,
  }) async {
    try {
      await methodChannel.invokeMethod(MethodConsts.initialize, config.toMap());
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// Identify a person using a unique userId, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  @override
  void identify(
      {required String userId,
      Map<String, dynamic> traits = const {}}) async {
    try {
      final payload = {
        TrackingConsts.userId: userId,
        TrackingConsts.traits: traits
      };
      methodChannel.invokeMethod(MethodConsts.identify, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  @override
  void track(
      {required String name,
      Map<String, dynamic> properties = const {}}) async {
    try {
      final payload = {
        TrackingConsts.name: name,
        TrackingConsts.properties: properties
      };
      methodChannel.invokeMethod(MethodConsts.track, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// Track a push metric
  @override
  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) async {
    try {
      final payload = {
        TrackingConsts.deliveryId: deliveryID,
        TrackingConsts.deliveryToken: deviceToken,
        TrackingConsts.metricEvent: event.name,
      };
      methodChannel.invokeMethod(MethodConsts.trackMetric, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// Track screen events to record the screens a user visits
  @override
  void screen(
      {required String title,
      Map<String, dynamic> properties = const {}}) async {
    try {
      final payload = {
        TrackingConsts.title: title,
        TrackingConsts.properties: properties
      };
      methodChannel.invokeMethod(MethodConsts.screen, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// Register a new device token with Customer.io, associated with the current active customer. If there
  /// is no active customer, this will fail to register the device
  @override
  void registerDeviceToken({required String deviceToken}) async {
    try {
      final payload = {
        TrackingConsts.token: deviceToken,
      };
      methodChannel.invokeMethod(MethodConsts.registerDeviceToken, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  /// Call this function to stop identifying a person.
  @override
  void clearIdentify() {
    try {
      methodChannel.invokeMethod(MethodConsts.clearIdentify);
    } on PlatformException catch (exception) {
      handleException(exception);
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
      handleException(exception);
    }
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  @override
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    try {
      final payload = {TrackingConsts.traits: attributes};
      methodChannel.invokeMethod(MethodConsts.setDeviceAttributes, payload);
    } on PlatformException catch (exception) {
      handleException(exception);
    }
  }

  void handleException(PlatformException exception) {
    if (kDebugMode) {
      print(exception);
    }
  }
}
