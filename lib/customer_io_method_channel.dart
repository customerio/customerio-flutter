import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'customer_io_config.dart';
import 'customer_io_const.dart';
import 'customer_io_platform_interface.dart';

/// An implementation of [CustomerIOPlatform] that uses method channels.
class CustomerIOMethodChannel extends CustomerIOPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('customer_io');

  @override
  Future<void> initialize({
    required CustomerIOConfig config,
  }) async {
    try {
      await methodChannel.invokeMethod(MethodConsts.initialize, config.toMap());
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void identify(
      {required String identifier,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.identifier: identifier,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.identify, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void track(
      {required String name,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.eventName: name,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.track, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void screen(
      {required String name,
      Map<String, dynamic> attributes = const {}}) async {
    try {
      final payload = {
        TrackingConsts.eventName: name,
        TrackingConsts.attributes: attributes
      };
      methodChannel.invokeMethod(MethodConsts.screen, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void clearIdentify() {
    try {
      methodChannel.invokeMethod(MethodConsts.clearIdentify);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void setProfileAttributes({required Map<String, dynamic> attributes}) {
    try {
      final payload = {TrackingConsts.attributes: attributes};
      methodChannel.invokeMethod(MethodConsts.setProfileAttributes, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }

  @override
  void setDeviceAttributes({required Map<String, dynamic> attributes}) {
    try {
      final payload = {TrackingConsts.attributes: attributes};
      methodChannel.invokeMethod(MethodConsts.setDeviceAttributes, payload);
    } on PlatformException catch (exception) {
      if (kDebugMode) {
        print(exception);
      }
    }
  }
}
