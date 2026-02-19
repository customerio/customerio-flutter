import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../customer_io_inapp.dart';
import 'inbox_message.dart';
import 'method_channel.dart';
import 'notification_inbox.dart';

/// The default instance of [CustomerIOMessagingInAppPlatform] to use
///
/// Platform-specific plugins should override this with their own
/// platform-specific class that extends [CustomerIOMessagingInAppPlatform]
/// when they register themselves.
///
/// Defaults to [CustomerIOMessagingInAppMethodChannel]
abstract class CustomerIOMessagingInAppPlatform extends PlatformInterface {
  CustomerIOMessagingInAppPlatform() : super(token: _token);

  static final Object _token = Object();

  static CustomerIOMessagingInAppPlatform _instance =
      CustomerIOMessagingInAppMethodChannel();

  static CustomerIOMessagingInAppPlatform get instance => _instance;

  static set instance(CustomerIOMessagingInAppPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  NotificationInbox? _inboxInstance;

  /// Access to the notification inbox for managing inbox messages
  NotificationInbox get inbox {
    _inboxInstance ??= NotificationInbox(platform: this);
    return _inboxInstance!;
  }

  void dismissMessage() {
    throw UnimplementedError('dismissMessage() has not been implemented.');
  }

  StreamSubscription subscribeToEventsListener(
      void Function(InAppEvent) onEvent) {
    throw UnimplementedError(
        'subscribeToEventsListener() has not been implemented.');
  }

  Future<List<InboxMessage>> fetchInboxMessages({String? topic}) {
    throw UnimplementedError('fetchInboxMessages() has not been implemented.');
  }

  Stream<List<InboxMessage>> inboxMessagesStream({String? topic}) {
    throw UnimplementedError('inboxMessagesStream() has not been implemented.');
  }

  void markInboxMessageOpened({required InboxMessage message}) {
    throw UnimplementedError(
        'markInboxMessageOpened() has not been implemented.');
  }

  void markInboxMessageUnopened({required InboxMessage message}) {
    throw UnimplementedError(
        'markInboxMessageUnopened() has not been implemented.');
  }

  void markInboxMessageDeleted({required InboxMessage message}) {
    throw UnimplementedError(
        'markInboxMessageDeleted() has not been implemented.');
  }

  void trackInboxMessageClicked(
      {required InboxMessage message, String? actionName}) {
    throw UnimplementedError(
        'trackInboxMessageClicked() has not been implemented.');
  }
}
