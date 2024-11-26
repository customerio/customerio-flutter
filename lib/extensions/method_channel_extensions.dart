import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

extension CustomerIOMethodChannelExtensions on MethodChannel {
  /// Invokes a native method and returns the result.
  /// Logs exceptions internally without propagating them.
  Future<T?> invokeNativeMethod<T>(String method,
      [Map<String, dynamic> arguments = const {}]) async {
    try {
      return await invokeMethod<T>(method, arguments);
    } on PlatformException catch (ex) {
      // Log the exception
      if (kDebugMode) {
        print("Error invoking native method '$method': ${ex.message}");
      }
      // Return null on failure
      return null;
    } catch (ex) {
      // Catch any other exceptions
      if (kDebugMode) {
        print("Unexpected error invoking native method '$method': $ex");
      }
      // Return null on unexpected errors
      return null;
    }
  }

  /// Simplifies invoking a native method that doesn't return a value.
  Future<void> invokeNativeMethodVoid(String method,
      [Map<String, dynamic> arguments = const {}]) async {
    return await invokeNativeMethod<void>(method, arguments);
  }
}
