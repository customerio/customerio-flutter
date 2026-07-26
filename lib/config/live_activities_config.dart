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
  final List<LiveActivityTemplate> types;

  /// Custom (app-defined) live activity type identifiers to enable.
  ///
  /// Custom types are rendered by the app on Android; on iOS they require a
  /// native Widget Extension and cannot be started from Dart.
  final List<String> customTypes;

  /// Branding for Live Notifications (Android only).
  final LiveActivitiesBranding? branding;

  LiveActivitiesConfig({
    this.types = const [],
    this.customTypes = const [],
    this.branding,
  });

  Map<String, dynamic> toMap() {
    return {
      'types': types.map((type) => type.rawValue).toList(),
      'customTypes': customTypes,
      'branding': branding?.toMap(),
    };
  }
}
