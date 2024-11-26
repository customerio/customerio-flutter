import 'dart:io';

import 'package:customer_io/extensions/method_channel_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '_native_constants.dart';
import 'platform_interface.dart';

/// An implementation of [CustomerIOMessagingPushPlatform] that uses method
/// channels.
class CustomerIOMessagingPushMethodChannel
    extends CustomerIOMessagingPushPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io_messaging_push');

  @override
  Future<String?> getRegisteredDeviceToken() {
    return methodChannel
        .invokeNativeMethod<String>(NativeMethods.getRegisteredDeviceToken);
  }

  @override
  Future<bool> onMessageReceived(Map<String, dynamic> message,
      {bool handleNotificationTrigger = true}) {
    if (Platform.isIOS) {
      /// Since push notifications on iOS work fine with multiple notification
      /// SDKs, we don't need to process them on iOS for now.
      /// Resolving future to true makes it easier for callers to avoid adding
      /// unnecessary platform specific checks.
      return Future.value(true);
    }

    return methodChannel
        .invokeNativeMethod<bool>(NativeMethods.onMessageReceived, arguments: {
      NativeMethodParams.message: message,
      NativeMethodParams.handleNotificationTrigger: handleNotificationTrigger,
    }).then((handled) => handled == true);
  }
}
