import 'customer_io_config.dart';
import 'customer_io_platform_interface.dart';

class CustomerIo {
  const CustomerIo._();

  static CustomerIOPlatform get _customerIO => CustomerIOPlatform.instance;

  static Future<String?> getPlatformVersion() {
    return _customerIO.getPlatformVersion();
  }

  static Future<void> initialize({
    required CustomerIOConfig config,
  }) {
    return _customerIO.initialize(config: config);
  }

  static void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) {
    return _customerIO.identify(identifier: identifier, attributes: attributes);
  }
}
