/// Enum to define the log levels.
/// Logs can be viewed in Xcode or Android studio.
enum CioLogLevel { none, error, info, debug }

/// Use this enum to specify the region your customer.io workspace is present in.
/// US - for data center in United States
/// EU - for data center in European Union
enum Region { us, eu }

/// Enum to specify the type of metric for tracking
enum MetricEvent { delivered, opened, converted, clicked }

/// Enum to specify the click behavior of push notification for Android
enum PushClickBehaviorAndroid {
  resetTaskStack(rawValue: 'RESET_TASK_STACK'),
  activityPreventRestart(rawValue: 'ACTIVITY_PREVENT_RESTART'),
  activityNoFlags(rawValue: 'ACTIVITY_NO_FLAGS');

  factory PushClickBehaviorAndroid.fromValue(String value) {
    switch (value) {
      case 'RESET_TASK_STACK':
        return PushClickBehaviorAndroid.resetTaskStack;
      case 'ACTIVITY_PREVENT_RESTART':
        return PushClickBehaviorAndroid.activityPreventRestart;
      case 'ACTIVITY_NO_FLAGS':
        return PushClickBehaviorAndroid.activityNoFlags;
      default:
        throw ArgumentError('Invalid value provided');
    }
  }

  const PushClickBehaviorAndroid({
    required this.rawValue,
  });

  final String rawValue;
}
