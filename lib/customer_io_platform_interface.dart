import 'package:customer_io/customer_io_config.dart';
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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> initialize({
    required CustomerIOConfig config,
  }) {
    throw UnimplementedError('config() has not been implemented.');
  }
}
