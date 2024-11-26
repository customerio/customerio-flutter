import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../customer_io_config.dart';
import '../customer_io_enums.dart';
import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'customer_io_platform_interface.dart';

/// An implementation of [CustomerIOPlatform] that uses method channels.
class CustomerIOMethodChannel extends CustomerIOPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io');

  /// To initialize the plugin
  @override
  Future<void> initialize({required CustomerIOConfig config}) {
    return methodChannel.invokeNativeMethodVoid(
        NativeMethods.initialize, config.toMap());
  }

  /// Identify a person using a unique userId, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  @override
  Future<void> identify(
      {required String userId, Map<String, dynamic> traits = const {}}) {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.identify, {
      NativeMethodParams.userId: userId,
      NativeMethodParams.traits: traits,
    });
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  @override
  Future<void> track(
      {required String name, Map<String, dynamic> properties = const {}}) {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.track, {
      NativeMethodParams.name: name,
      NativeMethodParams.properties: properties,
    });
  }

  /// Track a push metric
  @override
  Future<void> trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.trackMetric, {
      NativeMethodParams.deliveryId: deliveryID,
      NativeMethodParams.deliveryToken: deviceToken,
      NativeMethodParams.metricEvent: event.name,
    });
  }

  /// Track screen events to record the screens a user visits
  @override
  Future<void> screen(
      {required String title, Map<String, dynamic> properties = const {}}) {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.screen, {
      NativeMethodParams.title: title,
      NativeMethodParams.properties: properties,
    });
  }

  /// Register a new device token with Customer.io, associated with the current active customer. If there
  /// is no active customer, this will fail to register the device
  @override
  Future<void> registerDeviceToken({required String deviceToken}) {
    return methodChannel
        .invokeNativeMethodVoid(NativeMethods.registerDeviceToken, {
      NativeMethodParams.token: deviceToken,
    });
  }

  /// Call this function to stop identifying a person.
  @override
  Future<void> clearIdentify() {
    return methodChannel.invokeNativeMethodVoid(NativeMethods.clearIdentify);
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  @override
  Future<void> setProfileAttributes(
      {required Map<String, dynamic> attributes}) {
    return methodChannel
        .invokeNativeMethodVoid(NativeMethods.setProfileAttributes, {
      NativeMethodParams.attributes: attributes,
    });
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  @override
  Future<void> setDeviceAttributes({required Map<String, dynamic> attributes}) {
    return methodChannel
        .invokeNativeMethodVoid(NativeMethods.setDeviceAttributes, {
      NativeMethodParams.attributes: attributes,
    });
  }
}
