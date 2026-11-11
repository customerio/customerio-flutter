import 'dart:async';

/// A Customer.io silent push, which carries data for the app and shows
/// nothing. The same push can arrive more than once, so key your work on
/// [deliveryId].
class CustomerIOBackgroundPush {
  const CustomerIOBackgroundPush({
    required this.deliveryId,
    required this.deliveryToken,
    required this.data,
  });

  /// Identifies this delivery. Repeats of one push share it.
  final String deliveryId;

  /// The device token the push was sent to. With automatic push tracking off,
  /// pass it as `deviceToken` to `CustomerIO.instance.trackMetric` to record
  /// Delivered yourself.
  final String deliveryToken;

  /// The data set on the message, without the Customer.io delivery keys.
  final Map<String, String> data;
}

/// Handles a Customer.io silent push. Must be a top-level or static function
/// annotated with `@pragma('vm:entry-point')`, since on Android it can run in
/// a background isolate.
typedef BackgroundPushHandler =
    FutureOr<void> Function(CustomerIOBackgroundPush push);
