import 'package:flutter/services.dart';

import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'platform_interface.dart';

class CustomerIOLocationMethodChannel extends CustomerIOLocationPlatform {
  final MethodChannel methodChannel =
      const MethodChannel('customer_io_location');

  @override
  void setLastKnownLocation(
      {required double latitude, required double longitude}) {
    methodChannel.invokeNativeMethodVoid(NativeMethods.setLastKnownLocation, {
      NativeMethodParams.latitude: latitude,
      NativeMethodParams.longitude: longitude,
    });
  }

  @override
  void requestLocationUpdate() {
    methodChannel.invokeNativeMethodVoid(NativeMethods.requestLocationUpdate);
  }
}
