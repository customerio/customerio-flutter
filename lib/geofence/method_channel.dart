import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '_native_constants.dart';
import 'platform_interface.dart';

class CustomerIOGeofenceMethodChannel extends CustomerIOGeofencePlatform {
  final MethodChannel methodChannel =
      const MethodChannel('customer_io_geofence');

  static bool _warnedNotEnabled = false;

  /// Invokes a geofence method on the native side, handling all errors safely
  /// for fire-and-forget calls. Logs a one-time warning if the geofence module
  /// is not enabled.
  Future<void> _invokeGeofenceMethod(String method,
      [Map<String, dynamic> arguments = const {}]) async {
    try {
      await methodChannel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      if (!_warnedNotEnabled && kDebugMode) {
        _warnedNotEnabled = true;
        debugPrint('Customer.io: Geofence module is not enabled. '
            'To use geofence features, add the geofence subspec to your '
            'Podfile (iOS) or set customerio_geofence_enabled=true in '
            'gradle.properties (Android).');
      }
    } catch (ex) {
      if (kDebugMode) {
        debugPrint("Customer.io: Error invoking geofence method '$method': $ex");
      }
    }
  }

  @override
  void refreshFromCurrentLocation() {
    _invokeGeofenceMethod(NativeMethods.refreshFromCurrentLocation);
  }
}
