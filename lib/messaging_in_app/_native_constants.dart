/// Methods specific to In-App module.
class NativeMethods {
  static const String dismissMessage = "dismissMessage";
  static const String subscribeToInboxMessages = "subscribeToInboxMessages";
  static const String getInboxMessages = "getInboxMessages";
  static const String markInboxMessageOpened = "markInboxMessageOpened";
  static const String markInboxMessageUnopened = "markInboxMessageUnopened";
  static const String markInboxMessageDeleted = "markInboxMessageDeleted";
  static const String trackInboxMessageClicked = "trackInboxMessageClicked";
}

/// Method parameters specific to In-App module.
class NativeMethodParams {
  static const String topic = "topic";
  static const String message = "message";
  static const String actionName = "actionName";
  static const String messages = "messages";
}
