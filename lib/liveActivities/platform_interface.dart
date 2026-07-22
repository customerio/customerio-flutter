import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'live_activity_payload.dart';
import 'method_channel.dart';

/// The interface that implementations of the Live Activities module must implement.
///
/// Live Activities (iOS) / Live Notifications (Android) are exposed here. There is
/// intentionally no lifecycle event listener/stream, as neither native SDK exposes one.
abstract class CustomerIOLiveActivitiesPlatform extends PlatformInterface {
  CustomerIOLiveActivitiesPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOLiveActivitiesPlatform _instance =
      CustomerIOLiveActivitiesMethodChannel();

  static CustomerIOLiveActivitiesPlatform get instance => _instance;

  static set instance(CustomerIOLiveActivitiesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Starts a Live Activity for a built-in template and returns its activity id.
  Future<String> start(LiveActivityPayload payload) {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Updates a running Live Activity with the full desired state.
  ///
  /// ActivityKit replaces content-state wholesale, so [payload] must contain the
  /// complete desired state, not a partial diff.
  Future<void> update(String activityId, LiveActivityPayload payload) {
    throw UnimplementedError('update() has not been implemented.');
  }

  /// Ends a running Live Activity. Ending an unknown/already-ended id is a no-op.
  Future<void> end(String activityId) {
    throw UnimplementedError('end() has not been implemented.');
  }

  /// Starts a custom (app-defined) Live Activity type and returns its activity id.
  ///
  /// On Android the app renders the activity via its registered callback. On iOS
  /// custom types are rejected because they require a native Widget Extension and
  /// an `adopt(_:)` call; the returned future completes with an error.
  Future<String> startCustom(String activityType, Map<String, dynamic> data) {
    throw UnimplementedError('startCustom() has not been implemented.');
  }

  /// Reports an opened metric for a Live Activity deep link.
  ///
  /// Returns true if the SDK handled the url (iOS only); returns false on Android.
  Future<bool> handleDeepLinkOpen(String url) {
    throw UnimplementedError('handleDeepLinkOpen() has not been implemented.');
  }
}
