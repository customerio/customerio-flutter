import '../customer_io_enums.dart';

/// Branding applied to Live Notifications on Android.
///
/// This is Android-only; on iOS the Live Activity appearance is defined by the
/// app's Widget Extension and these values are ignored.
class LiveActivitiesBranding {
  /// Company/brand name shown on the notification.
  final String? companyName;

  /// Accent color as a `#RRGGBB` hex string.
  final String? accentColorHex;

  /// Name of a bundled drawable resource used as the logo.
  ///
  /// Preferred over [logoUrl] when both are set — it renders without a network
  /// round-trip, so the logo is present on the very first frame.
  final String? logoResource;

  /// Remote URL for a logo asset.
  final String? logoUrl;

  /// Name of a drawable resource used as the small icon.
  final String? smallIconResource;

  LiveActivitiesBranding({
    this.companyName,
    this.accentColorHex,
    this.logoResource,
    this.logoUrl,
    this.smallIconResource,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'accentColorHex': accentColorHex,
      'logoResource': logoResource,
      'logoUrl': logoUrl,
      'smallIconResource': smallIconResource,
    };
  }
}

/// Configuration for the Live Activities (iOS) / Live Notifications (Android) module.
class LiveActivitiesConfig {
  /// Built-in activity types to enable.
  ///
  /// Unrecognized identifiers are ignored, so a newer native template can't
  /// break an older wrapper build.
  ///
  /// Do not list [LiveActivityTemplate.custom] here — it is enabled by [customType],
  /// and both platforms drop it from this list.
  final List<LiveActivityTemplate> types;

  /// Your own reverse-DNS identifier for the custom activity type, e.g.
  /// `'com.myapp.rideshare'`. Setting it enables the custom template on both platforms.
  ///
  /// Start one with `LiveActivityPayload.custom(data: {...})`; the SDK reports it under
  /// this identifier and your campaigns target it by the same name.
  ///
  /// Singular by design: iOS resolves an activity's type from its Swift attributes type,
  /// and every custom activity shares one. A second identifier could not be told apart,
  /// so one is the limit rather than a silent mis-attribution.
  ///
  /// You must also render it yourself — `CIOCustomAttributes` in an iOS Widget Extension,
  /// and the `createLiveNotification` callback on Android.
  final String? customType;

  /// Branding for Live Notifications (Android only).
  final LiveActivitiesBranding? branding;

  LiveActivitiesConfig({
    this.types = const [],
    this.customType,
    this.branding,
  });

  Map<String, dynamic> toMap() {
    return {
      'types': types.map((type) => type.rawValue).toList(),
      'customType': customType,
      'branding': branding?.toMap(),
    };
  }
}
