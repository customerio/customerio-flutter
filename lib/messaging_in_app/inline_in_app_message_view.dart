import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Callback function for handling in-app message actions
typedef InAppMessageActionCallback = void Function(
  String actionValue, 
  String actionName, {
  String? messageId,
  String? deliveryId,
});

/// A Flutter widget that displays an inline in-app message using native platform views.
/// 
/// This widget wraps the native Android InlineInAppMessageView and iOS InlineMessageUIView 
/// and provides Flutter integration. The view will automatically show and hide based on 
/// whether there are messages available for the specified element ID.
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
  const InlineInAppMessageView({
    super.key,
    required this.elementId,
    this.onAction,
  });

  /// The element ID that identifies which message to display
  final String elementId;

  /// Callback function that gets called when a message action is triggered
  final InAppMessageActionCallback? onAction;

  @override
  State<InlineInAppMessageView> createState() => _InlineInAppMessageViewState();
}

class _InlineInAppMessageViewState extends State<InlineInAppMessageView> {
  MethodChannel? _methodChannel;
  double? _nativeHeight;
  double? _nativeWidth;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _methodChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'elementId': widget.elementId,
    };

    Widget platformView;

    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = AndroidView(
        viewType: 'customer_io_inline_in_app_message_view',
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{}.toSet(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformView = UiKitView(
        viewType: 'customer_io_inline_in_app_message_view',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        // height is 1.0 to avoid zero-height layout issues,
        // which cause Flutter to skip laying out the native view
        height: _nativeHeight ?? 1.0,
        width: _nativeWidth ?? double.infinity,
        child: platformView,
      ),
    );
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
      case 'onSizeChange':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final width = arguments['width'] as double?;
        final height = arguments['height'] as double?;
        if (mounted) {
          setState(() {
            // Treat height 0.0 as "no message" state, set to 1.0 to maintain layout
            _nativeHeight = (height == 0.0) ? 1.0 : height;
            _nativeWidth = width;
          });
        }
        break;
      case 'onStateChange':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final state = arguments['state'] as String;
        if (mounted) {
          if (state == 'NoMessageToDisplay') {
            setState(() {
              _nativeHeight = 1.0; // Unified no-message height
            });
          }
        }
        break;
      default:
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

  }

  /// Sets the element ID for the inline message view
  Future<void> _setElementId(String elementId) async {
    await _safeInvokeMethod('setElementId', elementId);
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

}