import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_interface.dart';

/// An implementation of [CustomerIOMessagingInAppPlatform] that uses method
/// channels.
class CustomerIOMessagingInAppMethodChannel
    extends CustomerIOMessagingInAppPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io_messaging_in_app');

  @override
  void dismissMessage() async {
    try {
      methodChannel.invokeMethod('dismissMessage');
    } on PlatformException catch (e) {
      handleException(e);
    }
  }

  void handleException(PlatformException exception) {
    if (kDebugMode) {
      print(exception);
    }
  }
}
