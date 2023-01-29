import 'dart:async';

import 'customer_io_config.dart';
import 'customer_io_inapp.dart';
import 'customer_io_platform_interface.dart';

class CustomerIO {
  const CustomerIO._();

  static CustomerIOPlatform get _customerIO => CustomerIOPlatform.instance;

  /// To initialize the plugin
  ///
  /// @param config includes required and optional configs etc
  static Future<void> initialize({
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
  static void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    return _customerIO.identify(identifier: identifier, attributes: attributes);
  }

  /// Call this function to stop identifying a person.
  ///
  /// If a profile exists, clearIdentify will stop identifying the profile.
  /// If no profile exists, request to clearIdentify will be ignored.
  static void clearIdentify() {
    _customerIO.clearIdentify();
  }

  /// To track user events like loggedIn, addedItemToCart etc.
  /// You may also track events with additional yet optional data.
  ///
  /// @param name event name to be tracked
  /// @param attributes (Optional) params to be sent with event
  static void track(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    return _customerIO.track(name: name, attributes: attributes);
  }

  /// Track screen events to record the screens a user visits
  ///
  /// @param name name of the screen user visited
  /// @param attributes (Optional) params to be sent with event
  static void screen(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    return _customerIO.screen(name: name, attributes: attributes);
  }

  /// Use this function to send custom device attributes
  /// such as app preferences, timezone etc
  ///
  /// @param attributes device attributes
  static void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    return _customerIO.setDeviceAttributes(attributes: attributes);
  }

  /// Set custom user profile information such as user preference, specific
  /// user actions etc
  ///
  /// @param attributes additional attributes for a user profile
  static void setProfileAttributes({required Map<String, dynamic> attributes}) {
    return _customerIO.setProfileAttributes(attributes: attributes);
  }

  static StreamSubscription subscribeToInAppMessages(
      void Function(InAppEvent) onEvent) {
    return _customerIO.subscribeToInAppMessages(onEvent);
  }
}
