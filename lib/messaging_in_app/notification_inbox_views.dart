import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Constants shared by the Visual Notification Inbox platform views.
///
/// The headless inbox data API (`getInboxMessages`/`subscribe`/`mark`/`track`) and the global
/// action `InboxEventListener` (`setInboxEventListener`) are bridged separately. These widgets
/// only render the native UI components:
///  - [NotificationInboxBell] is the branded bell that opens the SDK's own panel; its `onTap` is
///    observational.
///  - [NotificationInboxView] is the message list (no per-view callbacks).
class _InboxViewConstants {
  _InboxViewConstants._();

  // Platform view type ids — must match the native factory registrations.
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
  bool claimsDragGestures = false,
}) {
  // Flutter only forwards gestures a platform view wins in the gesture arena. Taps get through by
  // default, which is all the bell needs, but vertical drags stay with Flutter — so the message
  // list could not scroll at all. An eager recognizer makes the platform view claim the sequence
  // immediately, which is right for a view that scrolls its own content.
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers =
      claimsDragGestures
          ? <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                EagerGestureRecognizer.new,
              ),
            }
          : const <Factory<OneSequenceGestureRecognizer>>{};

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Hybrid composition (`initExpensiveAndroidView`) rather than `AndroidView`, which uses virtual
    // display mode. Under virtual display the native view renders into a texture that only refreshes
    // on some invalidations: Compose consumed drag events on the message list (verified on device —
    // DOWN plus a stream of MOVEs, all handled) while the visible frame never changed, so the list
    // appeared frozen. Hybrid composition puts the real view in the hierarchy and it repaints.
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: gestureRecognizers,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (PlatformViewCreationParams params) {
        final AndroidViewController controller =
            PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: const <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener(onPlatformViewCreated)
          ..create();
        return controller;
      },
    );
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    return UiKitView(
      viewType: viewType,
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
      gestureRecognizers: gestureRecognizers,
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

/// The Visual Notification Inbox bell. Tapping it opens the SDK's own inbox panel
/// — the host builds no inbox UI.
///
/// Place it wherever the app's layout calls for it. Remote branding still styles the
/// bell (colors, icon); branding's *position* is not applied, because the host owns
/// placement. Give it at least 88 logical pixels square: the native composition
/// insets its 56 bell by 16 per side, so a smaller box squeezes the circle onto the
/// glyph.
///
/// Platform note: iOS 16+ (the panel is a sheet with system detents); renders nothing
/// on earlier versions.
///
/// Example:
/// ```dart
/// const SizedBox(width: 88, height: 88, child: NotificationInboxBell())
/// ```
class NotificationInboxBell extends StatefulWidget {
  const NotificationInboxBell({
    super.key,
    this.onTap,
  });

  /// Called when the user taps the bell.
  ///
  /// Observational only — the SDK opens the panel itself, so there is nothing the
  /// host has to do in response.
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
      claimsDragGestures: true,
    );
  }
}
