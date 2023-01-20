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