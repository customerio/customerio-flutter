import 'dart:async';

import 'customer_io_config.dart';
import 'customer_io_enums.dart';
import 'customer_io_inapp.dart';
import 'customer_io_platform_interface.dart';
import 'messaging_in_app/platform_interface.dart';
import 'messaging_push/platform_interface.dart';

class CustomerIO {
  const CustomerIO._();

  // Singleton instance
  static const CustomerIO instance = CustomerIO._();

  static CustomerIOPlatform get _customerIO => CustomerIOPlatform.instance;

  static CustomerIOMessagingPushPlatform get _customerIOMessagingPush =>
      CustomerIOMessagingPushPlatform.instance;

  static CustomerIOMessagingInAppPlatform get _customerIOMessagingInApp =>
      CustomerIOMessagingInAppPlatform.instance;

  /// To initialize the plugin
  ///
  /// @param config includes required and optional configs etc
  Future<void> initialize({
    required CustomerIOConfig config,
  }) {
    return _customerIO.initialize(config: config);
  }

  /// Identify a person using a unique identifier, eg. email id.
  /// Note that you can identify only 1 profile at a time. In case, multiple
  /// identifiers are attempted to be identified, then the last identified profile
  /// will be removed automatically.
  ///
  /// @param identifier unique identifier for a profile
  /// @param attributes (Optional) params to set profile attributes
  void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    return _customerIO.identify(identifier: identifier, attributes: attributes);
  }

  /// Call this function to stop identifying a person.
  ///
  /// If a profile exists, clearIdentify will stop identifying the profile.
  /// If no profile exists, request to clearIdentify will be ignored.
  void clearIdentify() {
    _customerIO.clearIdentify();
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  ///
  /// @param name event name to be tracked
  /// @param attributes (Optional) params to be sent with event
  void track(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    return _customerIO.track(name: name, attributes: attributes);
  }

  /// Track a push metric
  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    return _customerIO.trackMetric(
        deliveryID: deliveryID, deviceToken: deviceToken, event: event);
  }

  /// Register a new device token with Customer.io, associated with the current active customer. If there
  /// is no active customer, this will fail to register the device
  void registerDeviceToken({required String deviceToken}) {
    return _customerIO.registerDeviceToken(deviceToken: deviceToken);
  }

  /// Track screen events to record the screens a user visits
  ///
  /// @param name name of the screen user visited
  /// @param attributes (Optional) params to be sent with event
  void screen(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    return _customerIO.screen(name: name, attributes: attributes);
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  ///
  /// @param attributes device attributes
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    return _customerIO.setDeviceAttributes(attributes: attributes);
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  ///
  /// @param attributes additional attributes for a user profile
  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    return _customerIO.setProfileAttributes(attributes: attributes);
  }

  /// Subscribes to an in-app event listener.
  ///
  /// [onEvent] - A callback function that will be called every time an in-app event occurs.
  /// The callback returns [InAppEvent].
  ///
  /// Returns a [StreamSubscription] that can be used to subscribe/unsubscribe from the event listener.
  StreamSubscription subscribeToInAppEventListener(
      void Function(InAppEvent) onEvent) {
    return _customerIO.subscribeToInAppEventListener(onEvent);
  }

  CustomerIOMessagingPushPlatform messagingPush() {
    return _customerIOMessagingPush;
  }

  CustomerIOMessagingInAppPlatform messagingInApp() {
    return _customerIOMessagingInApp;
  }
}
