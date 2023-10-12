import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:analytics/client.dart';
import 'package:analytics/event.dart';
import 'package:analytics/state.dart';

import 'customer_io_config.dart';
import 'customer_io_const.dart';
import 'customer_io_enums.dart';
import 'customer_io_inapp.dart';
import 'customer_io_platform_interface.dart';
import 'messaging_in_app/platform_interface.dart';
import 'messaging_push/platform_interface.dart';

class CustomerIO {
  const CustomerIO._();

  static CustomerIOPlatform get _customerIO => CustomerIOPlatform.instance;

  static CustomerIOMessagingPushPlatform get _customerIOMessagingPush =>
      CustomerIOMessagingPushPlatform.instance;

  static CustomerIOMessagingInAppPlatform get _customerIOMessagingInApp =>
      CustomerIOMessagingInAppPlatform.instance;

  static late Analytics analytics;

  /// To initialize the plugin
  ///
  /// @param config includes required and optional configs etc
  static Future<void> initialize({
    required CustomerIOConfig config,
  }) {
    String writeKey = "${config.siteId}:${config.apiKey}";
    Configuration analyticsConfig = Configuration(
      writeKey,
      debug: true,
      trackApplicationLifecycleEvents: false,
    );
    analytics = createClient(analyticsConfig);
    return _customerIO.initialize(config: config);
  }

  /// Identify a person using a unique identifier, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  ///
  /// @param identifier unique identifier for a profile
  /// @param attributes (Optional) params to set profile attributes
  static void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    analytics.identify(
        userId: identifier, userTraits: UserTraits.fromJson(attributes));
  }

  /// Call this function to stop identifying a person.
  ///
  /// If a profile exists, clearIdentify will stop identifying the profile.
  /// If no profile exists, request to clearIdentify will be ignored.
  static void clearIdentify() {
    analytics.identify(userId: null);
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  ///
  /// @param name event name to be tracked
  /// @param attributes (Optional) params to be sent with event
  static void track(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    analytics.track(name, properties: attributes);
  }

  /// Track a push metric
  static void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    final payload = {
      TrackingConsts.deliveryId: deliveryID,
      TrackingConsts.deliveryToken: deviceToken,
      TrackingConsts.metricEvent: event.name,
    };
    analytics.track("metric", properties: payload);
  }

  /// Register a new device token with Customer.io, associated with the current active customer. If there
  /// is no active customer, this will fail to register the device
  static void registerDeviceToken({required String deviceToken}) {
    // TODO: implement registerDeviceToken
  }

  /// Track screen events to record the screens a user visits
  ///
  /// @param name name of the screen user visited
  /// @param attributes (Optional) params to be sent with event
  static void screen(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    analytics.screen(name, properties: attributes);
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  ///
  /// @param attributes device attributes
  static void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    // TODO: implement setDeviceAttributes
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  ///
  /// @param attributes additional attributes for a user profile
  static void setProfileAttributes({required Map<String, dynamic> attributes}) {
    analytics.identify(userTraits: UserTraits.fromJson(attributes));
  }

  /// Subscribes to an in-app event listener.
  ///
  /// [onEvent] - A callback function that will be called every time an in-app event occurs.
  /// The callback returns [InAppEvent].
  ///
  /// Returns a [StreamSubscription] that can be used to subscribe/unsubscribe from the event listener.
  static StreamSubscription subscribeToInAppEventListener(
      void Function(InAppEvent) onEvent) {
    return _customerIO.subscribeToInAppEventListener(onEvent);
  }

  static CustomerIOMessagingPushPlatform messagingPush() {
    return _customerIOMessagingPush;
  }

  static CustomerIOMessagingInAppPlatform messagingInApp() {
    return _customerIOMessagingInApp;
  }
}
