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

  /// Remote URL for a logo asset.
  final String? logoUrl;

  /// Name of a drawable resource used as the small icon.
  final String? smallIconResource;

  LiveActivitiesBranding({
    this.companyName,
    this.accentColorHex,
    this.logoUrl,
    this.smallIconResource,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'accentColorHex': accentColorHex,
      'logoUrl': logoUrl,
      'smallIconResource': smallIconResource,
    };
  }
}

/// Configuration for the Live Activities (iOS) / Live Notifications (Android) module.
class LiveActivitiesConfig {
  /// Built-in templates to enable.
  final List<LiveActivityTemplate> templates;

  /// Custom (app-defined) live activity type identifiers to enable.
  ///
  /// Custom types are rendered by the app on Android; on iOS they require a
  /// native Widget Extension and cannot be started from Dart.
  final List<String> customTypes;

  /// Branding for Live Notifications (Android only).
  final LiveActivitiesBranding? branding;

  LiveActivitiesConfig({
    this.templates = const [],
    this.customTypes = const [],
    this.branding,
  });

  Map<String, dynamic> toMap() {
    return {
      'templates': templates.map((template) => template.rawValue).toList(),
      'customTypes': customTypes,
      'branding': branding?.toMap(),
    };
  }
}
