import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    developer.log(message);
  }
}

void debugError(String message, {Object? error, StackTrace? stackTrace}) {
  if (kDebugMode) {
    developer.log(message, error: error, stackTrace: stackTrace);
  }
}
