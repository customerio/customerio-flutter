import 'package:flutter/services.dart';

import '_native_constants.dart';
import 'platform_interface.dart';

class CustomerIOLocationMethodChannel extends CustomerIOLocationPlatform {
  final MethodChannel methodChannel =
      const MethodChannel('customer_io_location');

  /// Invokes a native location method, silently no-oping if the location
  /// module is not enabled (MissingPluginException).
  Future<void> _invokeIfAvailable(String method,
      [Map<String, dynamic> arguments = const {}]) async {
    try {
      await methodChannel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Location module is optional — silently no-op when not enabled
    }
  }

  @override
  void setLastKnownLocation(
      {required double latitude, required double longitude}) {
    _invokeIfAvailable(NativeMethods.setLastKnownLocation, {
      NativeMethodParams.latitude: latitude,
      NativeMethodParams.longitude: longitude,
    });
  }

  @override
  void requestLocationUpdate() {
    _invokeIfAvailable(NativeMethods.requestLocationUpdate);
  }
}
