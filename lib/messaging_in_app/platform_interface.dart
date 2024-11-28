import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../customer_io_inapp.dart';
import 'method_channel.dart';

/// The default instance of [CustomerIOMessagingInAppPlatform] to use
///
/// Platform-specific plugins should override this with their own
/// platform-specific class that extends [CustomerIOMessagingInAppPlatform]
/// when they register themselves.
///
/// Defaults to [CustomerIOMessagingInAppMethodChannel]
abstract class CustomerIOMessagingInAppPlatform extends PlatformInterface {
  CustomerIOMessagingInAppPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOMessagingInAppPlatform _instance =
      CustomerIOMessagingInAppMethodChannel();

  static CustomerIOMessagingInAppPlatform get instance => _instance;

  static set instance(CustomerIOMessagingInAppPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void dismissMessage() {
    throw UnimplementedError('dismissMessage() has not been implemented.');
  }

  StreamSubscription subscribeToInAppEventListener(
      void Function(InAppEvent) onEvent) {
    throw UnimplementedError(
        'subscribeToInAppEventListener() has not been implemented.');
  }
}
