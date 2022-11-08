import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'customer_io_platform_interface.dart';

/// An implementation of [CustomerIoPlatform] that uses method channels.
class MethodChannelCustomerIo extends CustomerIoPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
