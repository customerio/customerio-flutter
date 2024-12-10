import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';

import 'customer_io_config.dart';
import 'customer_io_enums.dart';
import 'data_pipelines/customer_io_platform_interface.dart';
import 'extensions/map_extensions.dart';
import 'messaging_in_app/platform_interface.dart';
import 'messaging_push/platform_interface.dart';

class CustomerIO {
  static CustomerIO? _instance;

  final CustomerIOPlatform _platform;
  final CustomerIOMessagingPushPlatform _pushMessaging;
  final CustomerIOMessagingInAppPlatform _inAppMessaging;

  /// Private constructor to enforce singleton pattern
  CustomerIO._({
    CustomerIOPlatform? platform,
    CustomerIOMessagingPushPlatform? pushMessaging,
    CustomerIOMessagingInAppPlatform? inAppMessaging,
  })  : _platform = platform ?? CustomerIOPlatform.instance,
        _pushMessaging =
            pushMessaging ?? CustomerIOMessagingPushPlatform.instance,
        _inAppMessaging =
            inAppMessaging ?? CustomerIOMessagingInAppPlatform.instance;

  /// Get the singleton instance of CustomerIO
  static CustomerIO get instance {
    if (_instance == null) {
      throw StateError(
        'CustomerIO SDK must be initialized before accessing instance.\n'
        'Call CustomerIO.initialize() first.',
      );
    }
    return _instance!;
  }

  /// For testing: create a new instance with mock implementations
  @visibleForTesting
  static CustomerIO createInstance({
    CustomerIOPlatform? platform,
    CustomerIOMessagingPushPlatform? pushMessaging,
    CustomerIOMessagingInAppPlatform? inAppMessaging,
  }) {
    _instance = CustomerIO._(
      platform: platform,
      pushMessaging: pushMessaging,
      inAppMessaging: inAppMessaging,
    );
    return _instance!;
  }

  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  /// Access push messaging functionality
  static CustomerIOMessagingPushPlatform get pushMessaging {
    return _instance?._pushMessaging ?? CustomerIOMessagingPushPlatform.instance;
  }

  /// Access in-app messaging functionality
  static CustomerIOMessagingInAppPlatform get inAppMessaging {
    return _instance?._inAppMessaging ?? CustomerIOMessagingInAppPlatform.instance;
  }

  /// To initialize the plugin
  ///
  /// @param config includes required and optional configs etc
  static Future<void> initialize({required CustomerIOConfig config}) async {
    // Check if already initialized
    if (_instance == null) {
      // Create new instance if not initialized
      _instance = CustomerIO._();
      // Initialize the platform
      await _instance!._platform.initialize(config: config);
    } else {
      log('CustomerIO SDK has already been initialized');
    }
  }

  /// Identify a person using a unique userId, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  ///
  /// @param userId unique identifier for a profile
  /// @param traits (Optional) params to set profile attributes
  void identify(
      {required String userId, Map<String, dynamic> traits = const {}}) {
    return _platform.identify(
        userId: userId, traits: traits.excludeNullValues());
  }

  /// Call this function to stop identifying a person.
  ///
  /// If a profile exists, clearIdentify will stop identifying the profile.
  /// If no profile exists, request to clearIdentify will be ignored.
  void clearIdentify() {
    return _platform.clearIdentify();
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  ///
  /// @param name event name to be tracked
  /// @param properties (Optional) params to be sent with event
  void track(
      {required String name, Map<String, dynamic> properties = const {}}) {
    return _platform.track(
        name: name, properties: properties.excludeNullValues());
  }

  /// Track a push metric
  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    return _platform.trackMetric(
        deliveryID: deliveryID, deviceToken: deviceToken, event: event);
  }

  /// Register a new device token with Customer.io, associated with the current active customer. If there
  /// is no active customer, this will fail to register the device
  void registerDeviceToken({required String deviceToken}) {
    return _platform.registerDeviceToken(deviceToken: deviceToken);
  }

  /// Track screen events to record the screens a user visits
  ///
  /// @param name name of the screen user visited
  /// @param attributes (Optional) params to be sent with event
  void screen(
      {required String title, Map<String, dynamic> properties = const {}}) {
    return _platform.screen(
        title: title, properties: properties.excludeNullValues());
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  ///
  /// @param attributes device attributes
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    return _platform.setDeviceAttributes(attributes: attributes);
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  ///
  /// @param attributes additional attributes for a user profile
  void setProfileAttributes(
      {required Map<String, dynamic> attributes}) {
    return _platform.setProfileAttributes(
        attributes: attributes.excludeNullValues());
  }
}
