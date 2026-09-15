import 'notification_inbox_accessibility_labels.dart';

class InAppConfig {
  final String siteId;

  /// Accessibility labels for the Visual Notification Inbox. Optional; an omitted label leaves
  /// that element unlabeled rather than falling back to English.
  final NotificationInboxAccessibilityLabels? accessibilityLabels;

  InAppConfig({required this.siteId, this.accessibilityLabels});

  Map<String, dynamic> toMap() {
    // Gated on the serialized map being non-empty, not on the object being non-null: a
    // NotificationInboxAccessibilityLabels with every field unset serializes to {}, and sending
    // that would make "the host configured nothing" indistinguishable from "the host configured
    // an empty object" on the native side, where both parsers key off the map's presence.
    final Map<String, dynamic>? labels = accessibilityLabels?.toMap();
    return {
      'siteId': siteId,
      if (labels != null && labels.isNotEmpty)
        'notificationInboxAccessibilityLabels': labels,
    };
  }
}
