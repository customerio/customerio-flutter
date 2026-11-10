/// Methods specific to Push module.
class NativeMethods {
  static const String getRegisteredDeviceToken = "getRegisteredDeviceToken";
  static const String onMessageReceived = "onMessageReceived";
  static const String registerBackgroundPushHandler =
      "registerBackgroundPushHandler";
  static const String clearBackgroundPushHandler = "clearBackgroundPushHandler";
}

/// Method parameters specific to Push module.
class NativeMethodParams {
  static const String message = "message";
  static const String handleNotificationTrigger = "handleNotificationTrigger";
  static const String dispatcherHandle = "dispatcherHandle";
  static const String handlerHandle = "handlerHandle";
  static const String deliveryId = "deliveryId";
  static const String deliveryToken = "deliveryToken";
  static const String data = "data";
}
