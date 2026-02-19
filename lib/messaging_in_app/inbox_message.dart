/// Represents an inbox message for a user.
///
/// Inbox messages are persistent messages that can be displayed in a message center or inbox UI.
/// They support read/unread states, expiration, and custom properties.
class InboxMessage {
  /// Internal queue identifier (for SDK use)
  final String queueId;

  /// Unique identifier for this message delivery
  final String? deliveryId;

  /// Optional expiration date. Messages may be hidden after this date.
  final DateTime? expiry;

  /// Date when the message was sent
  final DateTime sentAt;

  /// List of topic identifiers associated with this message. Empty list if no topics.
  final List<String> topics;

  /// Message type identifier
  final String type;

  /// Whether the user has opened/read this message
  final bool opened;

  /// Optional priority for message ordering. Lower values = higher priority (e.g., 1 is higher priority than 100)
  final int? priority;

  /// Custom key-value properties associated with this message
  final Map<String, dynamic> properties;

  InboxMessage({
    required this.queueId,
    this.deliveryId,
    this.expiry,
    required this.sentAt,
    required this.topics,
    required this.type,
    required this.opened,
    this.priority,
    required this.properties,
  });

  /// Creates an [InboxMessage] from a map received from native platform
  factory InboxMessage.fromMap(Map<String, dynamic> map) {
    return InboxMessage(
      queueId: map['queueId'] as String,
      deliveryId: map['deliveryId'] as String?,
      expiry: map['expiry'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['expiry'] as num).toInt())
          : null,
      sentAt:
          DateTime.fromMillisecondsSinceEpoch((map['sentAt'] as num).toInt()),
      topics: (map['topics'] as List<dynamic>?)?.cast<String>() ?? [],
      type: map['type'] as String,
      opened: map['opened'] as bool,
      priority: map['priority'] as int?,
      properties: (map['properties'] as Map<dynamic, dynamic>?)
              ?.cast<String, dynamic>() ??
          {},
    );
  }

  /// Converts this [InboxMessage] to a map for sending to native platform
  Map<String, dynamic> toMap() {
    return {
      'queueId': queueId,
      'deliveryId': deliveryId,
      'expiry': expiry?.millisecondsSinceEpoch,
      'sentAt': sentAt.millisecondsSinceEpoch,
      'topics': topics,
      'type': type,
      'opened': opened,
      'priority': priority,
      'properties': properties,
    };
  }

  @override
  String toString() {
    return 'InboxMessage{queueId: $queueId, deliveryId: $deliveryId, sentAt: $sentAt, opened: $opened, topics: $topics}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxMessage &&
          runtimeType == other.runtimeType &&
          queueId == other.queueId &&
          deliveryId == other.deliveryId;

  @override
  int get hashCode => queueId.hashCode ^ deliveryId.hashCode;
}
