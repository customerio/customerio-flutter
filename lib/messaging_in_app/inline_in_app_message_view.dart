import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Callback function for handling in-app message actions
typedef InAppMessageActionCallback = void Function(
  String actionValue, 
  String actionName, {
  String? messageId,
  String? deliveryId,
});

/// A Flutter widget that displays an inline in-app message using the native Android InlineInAppMessageView.
/// 
/// This widget wraps the native Android InlineInAppMessageView and provides Flutter integration.
/// It shows a progress indicator while the message is loading and hides it once the message is displayed.
/// If there is no message to display, the view will hide itself and display automatically when a new message is available.
///
/// Example usage:
/// ```dart
/// InlineInAppMessageView(
///   elementId: 'banner-message',
///   onAction: (actionValue, actionName) {
///     print('Action triggered: $actionName with value: $actionValue');
///   },
/// )
/// ```
class InlineInAppMessageView extends StatefulWidget {
  /// Creates an inline in-app message view.
  ///
  /// [elementId] is required and identifies which message to display.
  /// [onAction] is an optional callback for handling message actions.
  /// [progressTint] is an optional color for the progress indicator.
  const InlineInAppMessageView({
    super.key,
    required this.elementId,
    this.onAction,
    this.progressTint,
  });

  /// The element ID that identifies which message to display
  final String elementId;

  /// Callback function that gets called when a message action is triggered
  final InAppMessageActionCallback? onAction;

  /// Optional color for the progress indicator
  final Color? progressTint;

  @override
  State<InlineInAppMessageView> createState() => _InlineInAppMessageViewState();
}

class _InlineInAppMessageViewState extends State<InlineInAppMessageView> {
  MethodChannel? _methodChannel;

  @override
  Widget build(BuildContext context) {
    // Only build the platform view on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final creationParams = <String, dynamic>{
        'elementId': widget.elementId,
        if (widget.progressTint != null) 'progressTint': widget.progressTint!.toARGB32(),
      };
      
      return AndroidView(
        viewType: 'customer_io_inline_in_app_message_view',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }

    // Return an empty container for other platforms
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int id) {
    _methodChannel = MethodChannel('customer_io_inline_view_$id');
    _methodChannel!.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAction':
        if (widget.onAction != null) {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          final actionValue = arguments['actionValue'] as String;
          final actionName = arguments['actionName'] as String;
          final messageId = arguments['messageId'] as String?;
          final deliveryId = arguments['deliveryId'] as String?;
          widget.onAction!(
            actionValue, 
            actionName, 
            messageId: messageId,
            deliveryId: deliveryId,
          );
        }
        break;
    }
  }

  @override
  void didUpdateWidget(InlineInAppMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update element ID if it changed
    if (oldWidget.elementId != widget.elementId) {
      _setElementId(widget.elementId);
    }

    // Update progress tint if it changed
    if (oldWidget.progressTint != widget.progressTint && widget.progressTint != null) {
      _setProgressTint(widget.progressTint!);
    }
  }

  /// Sets the element ID for the inline message view
  Future<void> _setElementId(String elementId) async {
    await _safeInvokeMethod('setElementId', elementId);
  }

  /// Sets the progress tint color for the inline message view
  Future<void> _setProgressTint(Color color) async {
    await _safeInvokeMethod('setProgressTint', color.toARGB32());
  }

  /// Gets the current element ID from the native view
  Future<String?> getElementId() async {
    return await _safeInvokeMethod<String>('getElementId');
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

  @override
  void dispose() {
    _methodChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}