import 'inbox_message.dart';

/// Listener the host app registers to be notified when events occur on Visual
/// Notification Inbox messages.
///
/// Mirrors the native `InboxEventListener` (iOS/Android). Register it via
/// `CustomerIO.instance.inAppMessaging.setInboxEventListener(listener)` and
/// unregister by passing `null`.
///
/// IMPORTANT — action handling ownership:
/// Unlike the native listener (whose `messageActionTaken` returns a `Bool` to
/// optionally intercept the action), the Flutter MethodChannel is asynchronous,
/// so the bridge cannot round-trip a return value back to the SDK's calling
/// thread without risking a deadlock. Instead, while a Flutter listener is
/// registered the native forwarder always reports the action as handled by the
/// host (returns `true`), which suppresses the SDK's default navigation. This
/// means: **once you register an [InboxEventListener], your Flutter app owns
/// inbox action navigation** — the SDK will not open urls/deeplinks itself for
/// tapped actions. When no listener is registered, the SDK keeps its default
/// behavior. This matches the host-driven model of the in-app
/// [InAppEventListener].
///
/// All callbacks are observational (`void`). The SDK's built-in dismiss action
/// is always handled by the SDK regardless of this listener.
abstract class InboxEventListener {
  /// Called when a non-dismiss action is taken on an inbox message.
  ///
  /// Because a Flutter listener is registered, the SDK treats this action as
  /// handled by the host and performs no default navigation — the host is
  /// responsible for reacting to [actionValue] (typically the destination url).
  ///
  /// [message] - The [InboxMessage] the action was taken on.
  /// [actionName] - The Jist action name (e.g. `messageAction`).
  /// [actionValue] - The resolved action value, typically the action's url
  /// (may be empty if the action carried no value).
  void messageActionTaken(
      InboxMessage message, String actionName, String actionValue);

  /// Called when a message is first shown/rendered in the inbox view. Fired
  /// once per message (deduped by the SDK) while the view is displayed.
  ///
  /// [message] - The [InboxMessage] that was shown.
  void messageShown(InboxMessage message);

  /// Called when a message is marked opened (e.g. the inbox panel opening
  /// auto-marks the currently-shown unopened messages).
  ///
  /// [message] - The [InboxMessage] that was opened.
  void messageOpened(InboxMessage message);

  /// Called when a message is dismissed/removed from the inbox.
  ///
  /// [message] - The [InboxMessage] that was dismissed.
  void messageDismissed(InboxMessage message);
}
