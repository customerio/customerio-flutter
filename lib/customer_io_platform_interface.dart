import 'package:customer_io/customer_io_config.dart';
import 'package:customer_io/customer_io_enums.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'customer_io_method_channel.dart';

/// The default instance of [CustomerIOPlatform] to use
///
/// Platform-specific plugins should override this with their own
/// platform-specific class that extends [CustomerIOPlatform] when they
/// register themselves.
///
/// Defaults to [CustomerIOMethodChannel]
abstract class CustomerIOPlatform extends PlatformInterface {
  CustomerIOPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOPlatform _instance = CustomerIOMethodChannel();

  static CustomerIOPlatform get instance => _instance;

  static set instance(CustomerIOPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize({
    required CustomerIOConfig config,
  }) {
    throw UnimplementedError('config() has not been implemented.');
  }

  void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    throw UnimplementedError('identify() has not been implemented.');
  }

  void clearIdentify() {
    throw UnimplementedError('clearIdentify() has not been implemented.');
  }

  void track(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    throw UnimplementedError('track() has not been implemented.');
  }

  void trackMetric(
      {required String deliveryID,
      required String deviceToken,
      required MetricEvent event}) {
    throw UnimplementedError('trackMetric() has not been implemented.');
  }

  void registerDeviceToken({required String deviceToken}) {
    throw UnimplementedError('registerDeviceToken() has not been implemented.');
  }

  void screen(
      {required String name, Map<String, dynamic> attributes = const {}}) {
    throw UnimplementedError('screen() has not been implemented.');
  }

  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    throw UnimplementedError('setDeviceAttributes() has not been implemented.');
  }

  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    throw UnimplementedError(
        'setProfileAttributes() has not been implemented.');
  }
}
