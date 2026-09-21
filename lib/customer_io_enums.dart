/// Enum to define the log levels.
/// Logs can be viewed in Xcode or Android studio.
enum CioLogLevel { none, error, info, debug }

/// Use this enum to specify the region your customer.io workspace is present in.
/// US - for data center in United States
/// EU - for data center in European Union
enum Region { us, eu }

/// Enum to specify the type of metric for tracking
enum MetricEvent { delivered, opened, converted }

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

/// Enum class to define how CustomerIO SDK should handle screen view events.
/// all - to send screen events to destinations for analytics purposes and to display in-app messages.
/// inApp - to only display in-app messages and not send screen events to destinations.
enum ScreenView { all, inApp }

/// Built-in Live Activity (iOS) / Live Notification (Android) templates.
///
/// The raw values are the reverse-DNS identifiers Customer.io uses everywhere —
/// the `notificationType` on the wire, Android's `LiveNotificationType`, and
/// iOS's `CIOSegmentsAttributes.identifier` — so Dart, both native SDKs, and the
/// backend share one vocabulary. They are also the `type` inside
/// [LiveActivityPayload] maps.
enum LiveActivityTemplate {
  /// Segmented progress template (header, status, substatus, segment counts).
  segments(rawValue: 'io.customer.livenotifications.segments'),

  /// Countdown timer template (header, title, status message, end time).
  countdownTimer(rawValue: 'io.customer.livenotifications.countdowntimer'),

  /// Your own activity type, rendered by SwiftUI you write (iOS) and your
  /// `createLiveNotification` callback (Android).
  ///
  /// Unlike the members above this raw value is a marker, not an identifier — the
  /// activity is named by `LiveActivitiesConfig.customType` and reported under that
  /// name. It belongs in a payload's type, never in `LiveActivitiesConfig.types`.
  custom(rawValue: 'custom');

  const LiveActivityTemplate({required this.rawValue});

  final String rawValue;
}

/// Location tracking mode for the CustomerIO Location module.
enum LocationTrackingMode {
  /// Location tracking is disabled. All location operations no-op.
  off(rawValue: 'OFF'),

  /// Host app controls when location is captured (default).
  manual(rawValue: 'MANUAL'),

  /// SDK auto-captures location once per app launch when the app becomes active.
  onAppStart(rawValue: 'ON_APP_START');

  const LocationTrackingMode({required this.rawValue});

  final String rawValue;
}

/// How the geofence module acquires the device location it needs for
/// geofencing. Location acquired for geofencing is never sent to analytics.
enum GeofenceLocationMode {
  /// SDK acquires a fix itself when geofencing needs one and none is available
  /// (default).
  automatic(rawValue: 'AUTOMATIC'),

  /// Host drives it via `CustomerIO.geofence.refreshFromCurrentLocation()`.
  manual(rawValue: 'MANUAL');

  const GeofenceLocationMode({required this.rawValue});

  final String rawValue;
}

/// Color scheme used to render in-app messages.
///
/// Selects which of the light/dark variants authored in the Customer.io editor
/// is rendered. Use it when the app has its own appearance setting that can
/// disagree with the operating system: [auto] follows the device, while [light]
/// and [dark] pin the variant regardless of it.
///
/// Named with the `Cio` prefix because `ColorScheme` is already a Material
/// class, and hosts import `package:flutter/material.dart` alongside these
/// enums — an unprefixed name would be an ambiguous import in most apps.
///
/// The raw values are the wire contract shared with both native SDKs, which
/// match them lowercase and resolve anything unrecognized to `auto`. They are
/// declared explicitly rather than derived from the member names so a rename
/// cannot silently change what goes over the channel.
enum CioColorScheme {
  /// Follow the device's current appearance. The native default when unset.
  auto(rawValue: 'auto'),

  /// Always render the light variant, whatever the device is set to.
  light(rawValue: 'light'),

  /// Always render the dark variant, whatever the device is set to.
  dark(rawValue: 'dark');

  const CioColorScheme({required this.rawValue});

  final String rawValue;
}
