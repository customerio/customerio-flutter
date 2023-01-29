class InAppMessage {
  /// Unique identifier for the message
  final String messageId;

  /// Optional identifier for the delivery of this message
  final String? deliveryId;

  InAppMessage({
    required this.messageId,
    this.deliveryId,
  });
}

class InAppMessageActionEvent {
  final InAppMessage message;
  final String actionValue;
  final String actionName;

  InAppMessageActionEvent(
      {required this.message,
      required this.actionValue,
      required this.actionName});
}

abstract class InAppEventListener {
  void messageShown(InAppMessage message);

  void messageDismissed(InAppMessage message);

  void errorWithMessage(InAppMessage message);

  void messageActionTaken(
      InAppMessage message, String actionValue, String actionName);
}

class InAppEvent {
  final InAppMessage message;
  final String? actionValue;
  final String? actionName;
  final EventType eventType;

  InAppEvent({
    required this.eventType,
    required this.message,
    this.actionValue,
    this.actionName,
  });

  InAppEvent.fromMap(EventType type, Map<String?, dynamic?> map)
      : eventType = type,
        actionValue = map['actionValue'],
        actionName = map['actionName'],
        message = InAppMessage(
            messageId: map['messageId'], deliveryId: map['deliveryId']);
}

enum EventType {
  messageShown,
  messageDismissed,
  errorWithMessage,
  messageActionTaken
}
