import '../customer_io_enums.dart';

/// Configuration for the optional Geofence module.
///
/// Providing a [GeofenceConfig] opts the app into geofence monitoring; this also
/// enables the Location module, which geofence depends on.
class GeofenceConfig {
  /// How the module acquires the device location it needs for geofencing.
  /// Defaults to [GeofenceLocationMode.automatic].
  final GeofenceLocationMode locationMode;

  GeofenceConfig({this.locationMode = GeofenceLocationMode.automatic});

  Map<String, dynamic> toMap() {
    return {
      'locationMode': locationMode.rawValue,
    };
  }
}
