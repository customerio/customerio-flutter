import '../customer_io_enums.dart';
import 'notification_inbox_accessibility_labels.dart';

class InAppConfig {
  /// Workspace site ID. Optional when the SDK is set up with a public `pk_` key, which
  /// identifies the workspace.
  final String? siteId;

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

  /// Android-only in-app options. Ignored on iOS.
  final InAppConfigAndroid? android;

  InAppConfig({
    this.siteId,
    this.colorScheme,
    this.accessibilityLabels,
    this.android,
  });

  Map<String, dynamic> toMap() {
    // Gated on the serialized map being non-empty, not on the object being non-null: a
    // NotificationInboxAccessibilityLabels with every field unset serializes to {}, and sending
    // that would make "the host configured nothing" indistinguishable from "the host configured
    // an empty object" on the native side, where both parsers key off the map's presence.
    final Map<String, dynamic>? labels = accessibilityLabels?.toMap();
    final String? siteId = this.siteId;
    // Same gate as the labels: an InAppConfigAndroid with nothing set is not sent.
    final Map<String, dynamic>? android = this.android?.toMap();
    return {
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      // Omitted rather than defaulted to 'auto': the native SDKs already default to AUTO, and
      // sending a value the host never set would make "follow the device" indistinguishable
      // from an explicit choice.
      if (colorScheme != null) 'colorScheme': colorScheme!.rawValue,
      if (labels != null && labels.isNotEmpty)
        'notificationInboxAccessibilityLabels': labels,
      if (android != null && android.isNotEmpty) 'android': android,
    };
  }
}

/// In-app options that apply to Android only. They have no effect on iOS.
class InAppConfigAndroid {
  /// How modal in-app messages are shown on Android. Use
  /// [ModalPresentationAndroid.hostWindow] when your main activity uses
  /// `singleInstance`, a custom or empty `taskAffinity`, or a document launch
  /// mode, where modal messages can behave incorrectly. Defaults to
  /// [ModalPresentationAndroid.activity].
  final ModalPresentationAndroid? modalPresentation;

  InAppConfigAndroid({this.modalPresentation});

  Map<String, dynamic> toMap() {
    return {
      // Omitted when unset so the native SDK keeps its own default.
      if (modalPresentation != null)
        'modalPresentation': modalPresentation!.rawValue,
    };
  }
}
