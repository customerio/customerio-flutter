/// iOS-only SDK configuration; has no effect on Android.
class CustomerIOConfigIos {
  /// Whether geofence transitions are delivered in real time on a background cold-wake.
  /// When unset, defaults on if the geofence module is added, off otherwise.
  final bool? allowBackgroundDelivery;

  CustomerIOConfigIos({this.allowBackgroundDelivery});

  Map<String, dynamic> toMap() {
    return {
      'allowBackgroundDelivery': allowBackgroundDelivery,
    };
  }
}
