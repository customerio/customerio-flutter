import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../extensions/method_channel_extensions.dart';
import '_native_constants.dart';
import 'background_push.dart';
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
        .invokeNativeMethod<bool>(NativeMethods.onMessageReceived, {
      NativeMethodParams.message: message,
      NativeMethodParams.handleNotificationTrigger: handleNotificationTrigger,
    }).then((handled) => handled == true);
  }

  @override
  Future<void> setBackgroundPushHandler(BackgroundPushHandler? handler) async {
    if (handler == null) {
      methodChannel.setMethodCallHandler(null);
      await methodChannel
          .invokeNativeMethod<void>(NativeMethods.clearBackgroundPushHandler);
      return;
    }
    final handlerHandle = PluginUtilities.getCallbackHandle(handler);
    if (handlerHandle == null) {
      throw ArgumentError.value(handler, 'handler',
          "must be a top-level or static function annotated with @pragma('vm:entry-point')");
    }
    methodChannel.setMethodCallHandler(
        (call) async => handler(_backgroundPush(call.arguments as Map)));
    await methodChannel
        .invokeNativeMethod<void>(NativeMethods.registerBackgroundPushHandler, {
      NativeMethodParams.dispatcherHandle:
          PluginUtilities.getCallbackHandle(_backgroundPushDispatcher)!
              .toRawHandle(),
      NativeMethodParams.handlerHandle: handlerHandle.toRawHandle(),
    });
  }
}

/// Runs a push on the background isolate, with the handler found by the
/// handle native stored when the app registered it.
@visibleForTesting
Future<void> handleBackgroundIsolateCall(MethodCall call) async {
  final arguments = call.arguments as Map;
  final handler = PluginUtilities.getCallbackFromHandle(
    CallbackHandle.fromRawHandle(
        arguments[NativeMethodParams.handlerHandle] as int),
  ) as BackgroundPushHandler;
  await handler(_backgroundPush(arguments));
}

CustomerIOBackgroundPush _backgroundPush(Map arguments) =>
    CustomerIOBackgroundPush(
      deliveryId: arguments[NativeMethodParams.deliveryId] as String,
      deliveryToken: arguments[NativeMethodParams.deliveryToken] as String,
      data: Map<String, String>.from(
          arguments[NativeMethodParams.data] as Map),
    );

/// Entry point of the background isolate the Android plugin starts when no
/// app isolate registered a handler.
@pragma('vm:entry-point')
void _backgroundPushDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  const MethodChannel('customer_io_messaging_push_background')
      .setMethodCallHandler(handleBackgroundIsolateCall);
}
