
import 'customer_io_platform_interface.dart';

class CustomerIo {
  Future<String?> getPlatformVersion() {
    return CustomerIoPlatform.instance.getPlatformVersion();
  }
}
