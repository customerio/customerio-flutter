import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel.dart';

abstract class CustomerIOLocationPlatform extends PlatformInterface {
  CustomerIOLocationPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOLocationPlatform _instance = CustomerIOLocationMethodChannel();

  static CustomerIOLocationPlatform get instance => _instance;

  static set instance(CustomerIOLocationPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void setLastKnownLocation(
      {required double latitude, required double longitude}) {
    throw UnimplementedError(
        'setLastKnownLocation() has not been implemented.');
  }

  void requestLocationUpdate() {
    throw UnimplementedError(
        'requestLocationUpdate() has not been implemented.');
  }
}
