import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Constants shared by the Visual Notification Inbox platform views.
///
/// The headless inbox data API (`getInboxMessages`/`subscribe`/`mark`/`track`) and the global
/// action `InboxEventListener` (`setInboxEventListener`) are bridged separately. These widgets
/// only render the native UI components and surface per-view callbacks:
///  - [NotificationInboxOverlay] surfaces panel presentation changes (iOS only — see note).
///  - [NotificationInboxBell] surfaces taps.
///  - [NotificationInboxView] is the message list (no per-view callbacks).
class _InboxViewConstants {
  _InboxViewConstants._();

  // Platform view type ids — must match the native factory registrations.
  static const String overlayViewType =
      'customer_io_notification_inbox_overlay_view';
  static const String bellViewType =
      'customer_io_notification_inbox_bell_view';
  static const String listViewType = 'customer_io_notification_inbox_view';

  // Per-view MethodChannel name prefixes — must match the native channel prefixes.
  // The overlay has no channel: it owns panel presentation natively and reports nothing to Dart.
  static const String bellChannelPrefix =
      'customer_io_notification_inbox_bell_view_';
  static const String listChannelPrefix =
      'customer_io_notification_inbox_view_';

  // Method names (native -> Dart).
  static const String onTap = 'onTap';
}

/// Builds the platform-specific native view for a given [viewType], or a
/// zero-size box on unsupported platforms.
Widget _buildPlatformView({
  required String viewType,
  required ValueChanged<int> onPlatformViewCreated,
}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return UiKitView(
      viewType: viewType,
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
  return const SizedBox.shrink();
}

Future<void> _safeSetHandler(
  MethodChannel channel,
  Future<dynamic> Function(MethodCall)? handler,
) async {
  channel.setMethodCallHandler(handler);
}

/// Drop-in Visual Notification Inbox overlay: a floating bell plus a slide-out
/// panel containing the Jist-rendered message list. The host does not need to
/// build any inbox UI of its own.
///
/// Message taps/actions are handled by the global `InboxEventListener`
/// (`CustomerIO.inAppMessaging.setInboxEventListener`), which is bridged separately.
///
/// The overlay owns panel presentation natively (on iOS it presents a sheet with
/// system detents), so it takes no callbacks and reports no presentation state to
/// Dart.
///
/// Platform note: on iOS this requires iOS 16+ and renders nothing on earlier
/// versions. [NotificationInboxBell] and [NotificationInboxView] have no such floor,
/// so compose those two if you need to support iOS 15.
///
/// Example:
/// ```dart
/// NotificationInboxOverlay()
/// ```
class NotificationInboxOverlay extends StatelessWidget {
  const NotificationInboxOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return _buildPlatformView(
      viewType: _InboxViewConstants.overlayViewType,
      // No per-view channel: nothing flows back from the native overlay.
      onPlatformViewCreated: (_) {},
    );
  }
}

/// The Visual Notification Inbox bell only. The host opens its own inbox UI in
/// response to [onTap] (for example by navigating to a screen containing a
/// [NotificationInboxView]).
///
/// Example:
/// ```dart
/// NotificationInboxBell(
///   onTap: () => Navigator.of(context).pushNamed('/inbox'),
/// )
/// ```
class NotificationInboxBell extends StatefulWidget {
  const NotificationInboxBell({
    super.key,
    this.onTap,
  });

  /// Called when the user taps the bell.
  final VoidCallback? onTap;

  @override
  State<NotificationInboxBell> createState() => _NotificationInboxBellState();
}

class _NotificationInboxBellState extends State<NotificationInboxBell> {
  MethodChannel? _channel;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _safeSetHandler(channel, null);
    }
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final channel =
        MethodChannel('${_InboxViewConstants.bellChannelPrefix}$id');
    channel.setMethodCallHandler(_handleMethodCall);
    _channel = channel;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == _InboxViewConstants.onTap) {
      widget.onTap?.call();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlatformView(
      viewType: _InboxViewConstants.bellViewType,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}

/// The Jist-rendered Visual Notification Inbox message list. Embed this in your
/// own screen (a sheet, tab, or dedicated inbox page).
///
/// Message taps/actions are handled by the global `InboxEventListener`
/// (bridged separately); this widget renders the list only.
///
/// Example:
/// ```dart
/// const Expanded(child: NotificationInboxView())
/// ```
class NotificationInboxView extends StatefulWidget {
  const NotificationInboxView({super.key});

  @override
  State<NotificationInboxView> createState() => _NotificationInboxViewState();
}

class _NotificationInboxViewState extends State<NotificationInboxView> {
  MethodChannel? _channel;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      _safeSetHandler(channel, null);
    }
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    // A per-view channel is created for parity with the other inbox views and to
    // leave room for future native -> Dart callbacks; no methods are wired yet.
    _channel = MethodChannel('${_InboxViewConstants.listChannelPrefix}$id');
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlatformView(
      viewType: _InboxViewConstants.listViewType,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
