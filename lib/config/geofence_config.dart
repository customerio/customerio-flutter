/// Configuration for the optional Geofence module.
///
/// Geofence runs automatically once enabled and has no options yet. Providing a
/// [GeofenceConfig] opts the app into geofence monitoring; this also enables the
/// Location module, which geofence depends on.
class GeofenceConfig {
  GeofenceConfig();

  Map<String, dynamic> toMap() {
    return {};
  }
}
