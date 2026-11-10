import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'background_push.dart';
import 'method_channel.dart';

/// The default instance of [CustomerIOMessagingPushPlatform] to use
///
/// Platform-specific plugins should override this with their own
/// platform-specific class that extends [CustomerIOMessagingPushPlatform]
/// when they register themselves.
///
/// Defaults to [CustomerIOMessagingPushMethodChannel]
abstract class CustomerIOMessagingPushPlatform extends PlatformInterface {
  CustomerIOMessagingPushPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOMessagingPushPlatform _instance =
      CustomerIOMessagingPushMethodChannel();

  static CustomerIOMessagingPushPlatform get instance => _instance;

  static set instance(CustomerIOMessagingPushPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Method to get the device token registered with the Customer.io SDK.
  /// Returns a [Future] that resolves to the device token registered with
  /// Customer.io SDK.
  Future<String?> getRegisteredDeviceToken() {
    throw UnimplementedError(
        'getRegisteredDeviceToken() has not been implemented.');
  }

  /// Processes push notification received outside the CIO SDK. The method
  /// displays notification on device and tracks CIO metrics for push
  /// notification.
  ///
  /// [message] push payload received from FCM. The payload must contain data
  /// payload received in push notification.
  /// [handleNotificationTrigger] flag to indicate whether it should display the
  /// notification or not.
  /// `true` (default): The SDK will display the notification and track associated
  /// metrics.
  /// `false`: The SDK will only process the notification to track metrics but
  /// will not display any notification.
  /// Returns a [Future] that resolves to boolean indicating if the notification
  /// was handled by the SDK or not.
  Future<bool> onMessageReceived(Map<String, dynamic> message,
      {bool handleNotificationTrigger = true}) {
    throw UnimplementedError('onMessageReceived() has not been implemented.');
  }

  /// Registers [handler] to receive Customer.io silent pushes when Customer.io
  /// handles push in your app. Pass `null` to stop. The plugin remembers the
  /// registration across launches until then.
  ///
  /// [handler] must be a top-level or static function annotated with
  /// `@pragma('vm:entry-point')`. Register it at the start of `main`, so a push
  /// that launches the app in the background reaches it.
  ///
  /// On Android the handler runs from a WorkManager job, on the isolate that
  /// registered it while that engine runs, and otherwise on a background
  /// isolate the plugin starts, which shares no state with the rest of the
  /// app. On iOS it runs on the main isolate and needs `CioAppDelegateWrapper`.
  /// iOS gives a push about 30 seconds, and Customer.io completes it after 25.
  Future<void> setBackgroundPushHandler(BackgroundPushHandler? handler) {
    throw UnimplementedError(
        'setBackgroundPushHandler() has not been implemented.');
  }

  /// Handles push notification received when app is background. Since FCM
  /// itself displays the notification when app is background, this method makes
  /// it easier to determine whether the notification should be displayed or not.
  ///
  /// @see [onMessageReceived] for more details
  Future<bool> onBackgroundMessageReceived(Map<String, dynamic> message) =>
      onMessageReceived(message,
          handleNotificationTrigger: message['notification'] == null);
}
