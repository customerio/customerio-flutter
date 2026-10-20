import '../customer_io_enums.dart';
import 'notification_inbox_accessibility_labels.dart';

class InAppConfig {
  final String siteId;

  /// Color scheme used to render in-app messages. Defaults to
  /// [CioColorScheme.auto], which follows the device appearance. Set it when the app has its
  /// own appearance setting that can disagree with the operating system.
  ///
  /// Can be changed after initialization with
  /// `CustomerIO.inAppMessaging.setColorScheme`.
  final CioColorScheme? colorScheme;

  /// Accessibility labels for the Visual Notification Inbox. Optional; an omitted label leaves
  /// that element unlabeled rather than falling back to English.
  final NotificationInboxAccessibilityLabels? accessibilityLabels;

  InAppConfig({
    required this.siteId,
    this.colorScheme,
    this.accessibilityLabels,
  });

  Map<String, dynamic> toMap() {
    // Gated on the serialized map being non-empty, not on the object being non-null: a
    // NotificationInboxAccessibilityLabels with every field unset serializes to {}, and sending
    // that would make "the host configured nothing" indistinguishable from "the host configured
    // an empty object" on the native side, where both parsers key off the map's presence.
    final Map<String, dynamic>? labels = accessibilityLabels?.toMap();
    return {
      'siteId': siteId,
      // Omitted rather than defaulted to 'auto': the native SDKs already default to AUTO, and
      // sending a value the host never set would make "follow the device" indistinguishable
      // from an explicit choice.
      if (colorScheme != null) 'colorScheme': colorScheme!.rawValue,
      if (labels != null && labels.isNotEmpty)
        'notificationInboxAccessibilityLabels': labels,
    };
  }
}
