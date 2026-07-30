import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel.dart';

abstract class CustomerIOGeofencePlatform extends PlatformInterface {
  CustomerIOGeofencePlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOGeofencePlatform _instance =
      CustomerIOGeofenceMethodChannel();

  static CustomerIOGeofencePlatform get instance => _instance;

  static set instance(CustomerIOGeofencePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Requests a one-shot location fix and refreshes the nearby geofence set from
  /// it, without emitting a location analytics event or caching the fix. Call
  /// after the host app has been granted location permission; the SDK never
  /// requests permission itself.
  void refreshFromCurrentLocation() {
    throw UnimplementedError(
        'refreshFromCurrentLocation() has not been implemented.');
  }
}
