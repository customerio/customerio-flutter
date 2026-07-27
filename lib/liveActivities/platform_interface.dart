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

  /// Starts a Live Activity and returns its activity id.
  ///
  /// [payload] selects the template: a built-in one, or your own type named by
  /// `LiveActivitiesConfig.customType` via [LiveActivityPayload.custom].
  Future<String> start(LiveActivityPayload payload) {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Updates a running Live Activity with the full desired state.
  ///
  /// ActivityKit replaces content-state wholesale, so [payload] must contain the
  /// complete desired state, not a partial diff.
  ///
  /// On iOS this fails for an id this app session didn't start: the handle needed to
  /// update an activity is process-local, so the update genuinely did not happen.
  Future<void> update(String activityId, LiveActivityPayload payload) {
    throw UnimplementedError('update() has not been implemented.');
  }

  /// Ends a running Live Activity. Ending an unknown/already-ended id is a no-op.
  Future<void> end(String activityId, {LiveActivityPayload? payload}) {
    throw UnimplementedError('end() has not been implemented.');
  }
}
