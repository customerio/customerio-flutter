import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../customer_io_const.dart';
import 'platform_interface.dart';

/// An implementation of [CustomerIOPlatform] that uses method channels.
class CustomerIOMessagingPushMethodChannel
    extends CustomerIOMessagingPushPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io_messaging_push');

  @override
  Future<bool> onMessageReceived(Map<String, dynamic> message,
      {bool handleNotificationTrigger = true}) {
    if (Platform.isIOS) {
      /// Since push notifications on iOS work fine with multiple notification
      /// SDKs, we don't need to process them on iOS for now.
      /// Resolving future to true makes it easier for callers to avoid adding
      /// unnecessary platform specific checks.
      return Future.value(true);
    } else {
      try {
        final arguments = {
          TrackingConsts.message: message,
          TrackingConsts.handleNotificationTrigger: handleNotificationTrigger,
        };
        return methodChannel
            .invokeMethod(MethodConsts.onMessageReceived, arguments)
            .then((handled) => handled == true);
      } on PlatformException catch (exception) {
        handleException(exception);
        return Future.error(
            exception.message ?? "Error handling push notification");
      }
    }
  }

  void handleException(PlatformException exception) {
    if (kDebugMode) {
      print(exception);
    }
  }
}
