import '../customer_io_enums.dart';

class LocationConfig {
  final LocationTrackingMode trackingMode;

  LocationConfig({this.trackingMode = LocationTrackingMode.manual});

  Map<String, dynamic> toMap() {
    return {
      'trackingMode': trackingMode.rawValue,
    };
  }
}
