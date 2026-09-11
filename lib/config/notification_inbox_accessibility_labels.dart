/// Host-provided accessibility labels for the Visual Notification Inbox UI.
///
/// The SDK ships no text of its own in the visual inbox — the empty state is an icon and the
/// loading state is a spinner — so accessibility labels are the one place a string is still
/// needed. Because the SDK cannot know your app's language, every label is optional and null by
/// default, and an omitted label leaves that element unlabeled rather than falling back to
/// English. Pass strings already localized for the user's language.
///
/// ```dart
/// CustomerIO.initialize(
///   config: CustomerIOConfig(
///     cdpApiKey: '...',
///     inAppConfig: InAppConfig(
///       siteId: '...',
///       accessibilityLabels: NotificationInboxAccessibilityLabels(
///         bell: context.l10n.inboxBell,
///         bellWithUnreadCount: context.l10n.inboxUnread, // "{count} olasta aviseringar"
///         loadingIndicator: context.l10n.inboxLoading,
///         emptyState: context.l10n.inboxEmpty,
///       ),
///     ),
///   ),
/// );
/// ```
class NotificationInboxAccessibilityLabels {
  /// Label for the inbox bell button. Also used when the bell shows an unread badge but
  /// [bellWithUnreadCount] is not provided. null → the bell is announced as an unnamed button
  /// (it stays focusable and tappable; hiding it would leave screen reader users no way in).
  final String? bell;

  /// Label for the bell while it shows an unread badge. Include [countPlaceholder] where the
  /// number of unread messages should appear; it is substituted natively at render time.
  /// null → falls back to [bell].
  ///
  /// The badge itself is always hidden from assistive technologies, so the count is announced
  /// only through this label, never as bare digits appended to the button.
  ///
  /// This is a template rather than a callback because configuration crosses the platform
  /// channel, which carries data but not functions. One template cannot express languages whose
  /// plural rules need a distinct form per count.
  final String? bellWithUnreadCount;

  /// Label announced for the loading spinner.
  ///
  /// null behaves differently per platform: on Android the spinner keeps its indeterminate
  /// progress role, which TalkBack describes in the device's own language, while on iOS it is not
  /// an accessibility element at all, so VoiceOver skips it rather than focusing an unnamed
  /// control. Set a label if you want the loading state announced on both.
  final String? loadingIndicator;

  /// Label announced for the empty-state icon. null → the icon is treated as decorative.
  final String? emptyState;

  /// Replaced with the unread count inside [bellWithUnreadCount].
  static const String countPlaceholder = '{count}';

  const NotificationInboxAccessibilityLabels({
    this.bell,
    this.bellWithUnreadCount,
    this.loadingIndicator,
    this.emptyState,
  });

  /// Only the labels the host actually set are sent, so an unset label stays unset natively
  /// rather than arriving as an explicit null the parsers would have to distinguish.
  Map<String, dynamic> toMap() {
    return {
      if (bell != null) 'bell': bell,
      if (bellWithUnreadCount != null) 'bellWithUnreadCount': bellWithUnreadCount,
      if (loadingIndicator != null) 'loadingIndicator': loadingIndicator,
      if (emptyState != null) 'emptyState': emptyState,
    };
  }
}
