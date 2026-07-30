/// Methods specific to In-App module.
class NativeMethods {
  static const String dismissMessage = "dismissMessage";
  static const String subscribeToInboxMessages = "subscribeToInboxMessages";
  static const String getInboxMessages = "getInboxMessages";
  static const String markInboxMessageOpened = "markInboxMessageOpened";
  static const String markInboxMessageUnopened = "markInboxMessageUnopened";
  static const String markInboxMessageDeleted = "markInboxMessageDeleted";
  static const String trackInboxMessageClicked = "trackInboxMessageClicked";

  // Inbox event listener registration (Dart -> native)
  static const String registerInboxEventListener = "registerInboxEventListener";
  static const String unregisterInboxEventListener =
      "unregisterInboxEventListener";

  // Inbox event listener callbacks (native -> Dart). Distinct names so they do
  // not collide with the in-app messageShown/messageDismissed/messageActionTaken
  // that share the same `customer_io_messaging_in_app` channel.
  static const String inboxMessageActionTaken = "inboxMessageActionTaken";
  static const String inboxMessageShown = "inboxMessageShown";
  static const String inboxMessageOpened = "inboxMessageOpened";
  static const String inboxMessageDismissed = "inboxMessageDismissed";
}

/// Method parameters specific to In-App module.
class NativeMethodParams {
  static const String topic = "topic";
  static const String message = "message";
  static const String actionName = "actionName";
  static const String messages = "messages";
}
