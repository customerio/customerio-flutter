import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '_native_constants.dart';
import 'platform_interface.dart';

class CustomerIOLocationMethodChannel extends CustomerIOLocationPlatform {
  final MethodChannel methodChannel =
      const MethodChannel('customer_io_location');

  static bool _warnedNotEnabled = false;

  /// Invokes a location method on the native side, handling all errors safely
  /// for fire-and-forget calls. Logs a one-time warning if the location module
  /// is not enabled.
  Future<void> _invokeLocationMethod(String method,
      [Map<String, dynamic> arguments = const {}]) async {
    try {
      await methodChannel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      if (!_warnedNotEnabled && kDebugMode) {
        _warnedNotEnabled = true;
        debugPrint('Customer.io: Location module is not enabled. '
            'To use location features, add the location subspec to your '
            'Podfile (iOS) or set customerio_location_enabled=true in '
            'gradle.properties (Android).');
      }
    } catch (ex) {
      if (kDebugMode) {
        debugPrint("Customer.io: Error invoking location method '$method': $ex");
      }
    }
  }

  @override
  void setLastKnownLocation(
      {required double latitude, required double longitude}) {
    _invokeLocationMethod(NativeMethods.setLastKnownLocation, {
      NativeMethodParams.latitude: latitude,
      NativeMethodParams.longitude: longitude,
    });
  }

  @override
  void requestLocationUpdate() {
    _invokeLocationMethod(NativeMethods.requestLocationUpdate);
  }
}
