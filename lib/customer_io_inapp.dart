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

/// Class that holds information about the InAppMessageActionEvent.
class InAppMessageActionEvent {
  /// The InAppMessage object.
  final InAppMessage message;

  /// The value of the action taken on the InAppMessage.
  final String actionValue;

  /// The name of the action taken on the InAppMessage.
  final String actionName;

  /// Constructor for the InAppMessageActionEvent.
  ///
  /// [message] - The InAppMessage object. Required.
  /// [actionValue] - The value of the action taken on the InAppMessage. Required.
  /// [actionName] - The name of the action taken on the InAppMessage. Required.
  InAppMessageActionEvent({
    required this.message,
    required this.actionValue,
    required this.actionName,
  });
}

/// Abstract class that defines callbacks for In-App events.
abstract class InAppEventListener {
  /// Callback for when an In-App message is shown.
  ///
  /// [message] - The InAppMessage object.
  void messageShown(InAppMessage message);

  /// Callback for when an In-App message is dismissed.
  ///
  /// [message] - The InAppMessage object.
  void messageDismissed(InAppMessage message);

  /// Callback for when an error occurs with an In-App message.
  ///
  /// [message] - The InAppMessage object.
  void errorWithMessage(InAppMessage message);

  /// Callback for when an action is taken on an In-App message.
  ///
  /// [message] - The InAppMessage object.
  /// [actionValue] - The value of the action taken on the InAppMessage.
  /// [actionName] - The name of the action taken on the InAppMessage.
  void messageActionTaken(
      InAppMessage message, String actionValue, String actionName);
}

/// Class that holds information about the InAppEvent.
class InAppEvent {
  /// The InAppMessage object.
  final InAppMessage message;

  /// The value of the action taken on the InAppMessage.
  final String? actionValue;

  /// The name of the action taken on the InAppMessage.
  final String? actionName;

  /// The type of event.
  final EventType eventType;

  /// Constructor for the InAppEvent.
  ///
  /// [eventType] - The type of event. Required.
  /// [message] - The InAppMessage object. Required.
  /// [actionValue] - The value of the action taken on the InAppMessage.
  /// [actionName] - The name of the action taken on the InAppMessage.
  InAppEvent({
    required this.eventType,
    required this.message,
    this.actionValue,
    this.actionName,
  });

  /// Constructor for creating an InAppEvent from a map.
  ///
  /// [type] - The type of event.
  /// [map] - The map containing the values for creating the InAppEvent.
  InAppEvent.fromMap(EventType type, Map<String?, dynamic> map)
      : eventType = type,
        actionValue = map['actionValue'],
        actionName = map['actionName'],
        message = InAppMessage(
            messageId: map['messageId'], deliveryId: map['deliveryId']);
}

/// Enum to represent the type of event.
enum EventType {
  messageShown,
  messageDismissed,
  errorWithMessage,
  messageActionTaken
}
