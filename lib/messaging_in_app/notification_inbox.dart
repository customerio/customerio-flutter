import 'dart:async';

import 'inbox_message.dart';
import 'platform_interface.dart';

/// Manages inbox messages for the current user.
///
/// Inbox messages are persistent messages that users can view, mark as read/unread, and delete.
/// Messages are automatically fetched and kept in sync for identified users.
class NotificationInbox {
  final CustomerIOMessagingInAppPlatform _platform;

  NotificationInbox({CustomerIOMessagingInAppPlatform? platform})
      : _platform = platform ?? CustomerIOMessagingInAppPlatform.instance;

  /// Fetches inbox messages asynchronously.
  ///
  /// @param topic Optional topic filter. If provided, only messages
  ///              that have this topic in their topics list are returned.
  ///              If null, all messages are returned.
  /// @return Future that resolves to a list of inbox messages
  Future<List<InboxMessage>> fetchMessages({String? topic}) {
    return _platform.fetchMessages(topic: topic);
  }

  /// Returns a stream that emits inbox messages whenever they change.
  ///
  /// The stream immediately emits the current messages when subscribed,
  /// then emits again whenever messages are added, updated, or removed.
  ///
  /// Usage: `inbox.messages().listen((messages) { ... })`
  ///
  /// @param topic Optional topic filter. If provided, stream only emits messages
  ///              that have this topic in their topics list. If null, all messages are emitted.
  /// @return Stream of inbox messages
  Stream<List<InboxMessage>> messages({String? topic}) {
    return _platform.messages(topic: topic);
  }

  /// Marks an inbox message as opened/read.
  /// Updates local state immediately and syncs with the server.
  ///
  /// @param message The inbox message to mark as opened
  void markMessageOpened(InboxMessage message) {
    _platform.markInboxMessageOpened(message: message);
  }

  /// Marks an inbox message as unopened/unread.
  /// Updates local state immediately and syncs with the server.
  ///
  /// @param message The inbox message to mark as unopened
  void markMessageUnopened(InboxMessage message) {
    _platform.markInboxMessageUnopened(message: message);
  }

  /// Marks an inbox message as deleted.
  /// Removes the message from local state and syncs with the server.
  ///
  /// @param message The inbox message to mark as deleted
  void markMessageDeleted(InboxMessage message) {
    _platform.markInboxMessageDeleted(message: message);
  }

  /// Tracks a click event for an inbox message.
  /// Sends metric event to data pipelines to track message interaction.
  ///
  /// @param message The inbox message that was clicked
  /// @param actionName Optional name of the action clicked (e.g., "view_details", "dismiss")
  void trackMessageClicked(InboxMessage message, {String? actionName}) {
    _platform.trackInboxMessageClicked(
        message: message, actionName: actionName);
  }
}
