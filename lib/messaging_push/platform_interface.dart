import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel.dart';

/// The default instance of [CustomerIOMessagingPushPlatform] to use
///
/// Platform-specific plugins should override this with their own
/// platform-specific class that extends [CustomerIOPlatform] when they
/// register themselves.
///
/// Defaults to [CustomerIOMethodChannel]
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

  /// Handles push notification received when app is background. Since FCM
  /// itself displays the notification when app is background, this method makes
  /// it easier to determine whether the notification should be displayed or not.
  ///
  /// @see [onMessageReceived] for more details
  Future<bool> onBackgroundMessageReceived(Map<String, dynamic> message) =>
      onMessageReceived(message,
          handleNotificationTrigger: message.containsKey('notification'));
}
