import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Constants for inline in-app message view implementation
class _InlineMessageConstants {
  _InlineMessageConstants._(); // Prevent instantiation

  // Platform view configuration
  static const String viewType = 'customer_io_inline_in_app_message_view';
  static const String channelPrefix = 'customer_io_inline_view_';

  // Animation and layout
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const double fallbackHeight = 1.0;

  // Method names
  static const String setElementId = 'setElementId';
  static const String getElementId = 'getElementId';
  static const String cleanup = 'cleanup';
  static const String onAction = 'onAction';
  static const String onSizeChange = 'onSizeChange';
  static const String onStateChange = 'onStateChange';

  // Argument keys
  static const String elementId = 'elementId';
  static const String actionValue = 'actionValue';
  static const String actionName = 'actionName';
  static const String messageId = 'messageId';
  static const String deliveryId = 'deliveryId';
  static const String width = 'width';
  static const String height = 'height';
  static const String state = 'state';

  // State values
  static const String noMessageToDisplay = 'NoMessageToDisplay';
}

/// Represents an in-app message with its metadata
class InAppMessage {
  /// Creates an in-app message instance
  const InAppMessage({
    required this.messageId,
    this.deliveryId,
    this.elementId,
  });

  /// The unique identifier for the message
  final String messageId;

  /// The delivery/campaign identifier (optional)
  final String? deliveryId;

  /// The element identifier for inline messages (optional)
  final String? elementId;

  @override
  String toString() =>
      'InAppMessage(messageId: $messageId, deliveryId: $deliveryId, elementId: $elementId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InAppMessage &&
        other.messageId == messageId &&
        other.deliveryId == deliveryId &&
        other.elementId == elementId;
  }

  @override
  int get hashCode =>
      messageId.hashCode ^ deliveryId.hashCode ^ elementId.hashCode;
}

/// Callback function for handling in-app message action clicks
typedef InAppMessageActionClickCallback = void Function(
  InAppMessage message,
  String actionValue,
  String actionName,
);

/// A Flutter widget that displays an inline in-app message using native platform views.
///
/// This widget wraps the native Android InlineInAppMessageView and iOS InlineMessageUIView
/// and provides Flutter integration. The view will automatically show and hide based on
/// whether there are messages available for the specified element ID. When no message
/// is available, the widget is hidden using the Offstage widget to prevent layout issues.
///
/// Example usage:
/// ```dart
/// InlineInAppMessageView(
///   elementId: 'banner-message',
///   onActionClick: (message, actionValue, actionName) {
///     print('Action clicked: $actionName with value: $actionValue');
///     print('Message ID: ${message.messageId}');
///   },
/// )
/// ```
class InlineInAppMessageView extends StatefulWidget {
  /// Creates an inline in-app message view.
  ///
  /// [elementId] is required and identifies which message to display.
  /// [onActionClick] is an optional callback for handling message action clicks.
  const InlineInAppMessageView({
    super.key,
    required this.elementId,
    this.onActionClick,
  });

  /// The element ID that identifies which message to display
  final String elementId;

  /// Callback function that gets called when a message action is clicked
  final InAppMessageActionClickCallback? onActionClick;

  @override
  State<InlineInAppMessageView> createState() => _InlineInAppMessageViewState();
}

class _InlineInAppMessageViewState extends State<InlineInAppMessageView> {
  MethodChannel? _methodChannel;
  double? _nativeHeight;
  double? _nativeWidth;
  // Initially hide the view until message content is available
  bool _offstage = true;
  // Tracks pending offstage toggle after animation delay
  Timer? _offstageTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _offstageTimer?.cancel();
    _methodChannel?.setMethodCallHandler(null);
    // Explicitly call cleanup on iOS side
    _safeInvokeMethod(_InlineMessageConstants.cleanup);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      _InlineMessageConstants.elementId: widget.elementId,
    };

    Widget platformView;

    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = AndroidView(
        viewType: _InlineMessageConstants.viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers:
            const <Factory<OneSequenceGestureRecognizer>>{}.toSet(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: _InlineMessageConstants.viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return const SizedBox.shrink();
    }

    // Offstage message view when native height is missing or fallback (1.0)
    // Prevents layout issues due to zero-height native view
    return Offstage(
      offstage: _offstage,
      child: AnimatedSize(
        duration: _InlineMessageConstants.animationDuration,
        child: SizedBox(
          // Use fallback height to ensure native view is laid out,
          // as a height of 0 may cause the platform view to be skipped
          height: _nativeHeight ?? _InlineMessageConstants.fallbackHeight,
          width: _nativeWidth ?? double.infinity,
          child: platformView,
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    _methodChannel =
        MethodChannel('${_InlineMessageConstants.channelPrefix}$id');
    _methodChannel!.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case _InlineMessageConstants.onAction:
        if (widget.onActionClick != null) {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          final actionValue =
              arguments[_InlineMessageConstants.actionValue] as String;
          final actionName =
              arguments[_InlineMessageConstants.actionName] as String;
          final messageId =
              arguments[_InlineMessageConstants.messageId] as String?;
          final deliveryId =
              arguments[_InlineMessageConstants.deliveryId] as String?;

          final message = InAppMessage(
            messageId: messageId ?? '',
            deliveryId: deliveryId,
            elementId: widget.elementId,
          );

          widget.onActionClick!(message, actionValue, actionName);
        }
        break;
      case _InlineMessageConstants.onSizeChange:
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final width = arguments[_InlineMessageConstants.width] as double?;
        final height = arguments[_InlineMessageConstants.height] as double?;
        if (mounted) {
          // Treat height 0.0 as "no message" state, set to fallback height to maintain layout
          final newHeight = (height == 0.0)
              ? _InlineMessageConstants.fallbackHeight : height;
          _updateViewState(
            width: width,
            height: newHeight,
          );
        }
        break;
      case _InlineMessageConstants.onStateChange:
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final state = arguments[_InlineMessageConstants.state] as String;
        if (mounted) {
          if (state == _InlineMessageConstants.noMessageToDisplay) {
            // Unified no-message height
            _updateViewState(width: _nativeWidth,
                height: _InlineMessageConstants.fallbackHeight);
          }
        }
        break;
      default:
        break;
    }
  }

  /// Updates native view dimensions and toggles offstage state appropriately.
  /// Makes the view visible immediately for smooth expand animations,
  /// and delays hiding until after the animation completes.
  void _updateViewState({required double? width, required double? height}) {
    final shouldOffstage = (height ?? 0.0) <=
        _InlineMessageConstants.fallbackHeight;

    // If becoming visible, update offstage immediately
    if (!shouldOffstage && _offstage) {
      setState(() {
        _offstage = false;
        _nativeWidth = width;
        _nativeHeight = height;
      });
      return;
    }

    // If hiding, update size now, but delay offstage toggle until after animation
    setState(() {
      _nativeWidth = width;
      _nativeHeight = height;
    });

    // Schedule hide only if not already scheduled
    if (shouldOffstage && !_offstage && _offstageTimer == null) {
      _offstageTimer = Timer(_InlineMessageConstants.animationDuration, () {
        if (mounted) {
          setState(() {
            _offstage = true;
          });
        }
        _offstageTimer = null; // Clear the timer reference
      });
    }
  }

  @override
  void didUpdateWidget(InlineInAppMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update element ID if it changed
    if (oldWidget.elementId != widget.elementId) {
      _setElementId(widget.elementId);
    }
  }

  /// Sets the element ID for the inline message view
  Future<void> _setElementId(String elementId) async {
    await _safeInvokeMethod(_InlineMessageConstants.setElementId, elementId);
  }

  /// Gets the current element ID from the native view
  Future<String?> getElementId() async {
    return await _safeInvokeMethod<String>(
        _InlineMessageConstants.getElementId);
  }

  /// Safely invokes a method channel method with automatic error handling
  Future<T?> _safeInvokeMethod<T>(String method, [dynamic arguments]) async {
    if (_methodChannel == null) return null;

    try {
      return await _methodChannel!.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to invoke $method: ${e.message}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected error invoking $method: $e');
      }
      return null;
    }
  }
}
