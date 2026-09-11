import 'notification_inbox_accessibility_labels.dart';

class InAppConfig {
  final String siteId;

  /// Accessibility labels for the Visual Notification Inbox. Optional; an omitted label leaves
  /// that element unlabeled rather than falling back to English.
  final NotificationInboxAccessibilityLabels? accessibilityLabels;

  InAppConfig({required this.siteId, this.accessibilityLabels});

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
      if (accessibilityLabels != null)
        'notificationInboxAccessibilityLabels': accessibilityLabels!.toMap(),
    };
  }
}
