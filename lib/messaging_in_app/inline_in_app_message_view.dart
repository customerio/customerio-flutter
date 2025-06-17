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

/// Callback function for handling height changes in the native view
typedef HeightChangeCallback = void Function(double height);

/// Callback function for handling size changes (width and height) in the native view
typedef SizeChangeCallback = void Function({double? width, double? height, double? duration});

/// Callback function for handling loading state changes
typedef StateChangeCallback = void Function(String state);

/// A Flutter widget that displays an inline in-app message using native platform views.
/// 
/// This widget wraps the native Android InlineInAppMessageView and iOS GistInlineInAppMessageView 
/// and provides Flutter integration. It shows a progress indicator while the message is loading 
/// and hides it once the message is displayed. If there is no message to display, the view will 
/// hide itself and display automatically when a new message is available.
///
/// Example usage:
/// ```dart
/// InlineInAppMessageView(
///   elementId: 'banner-message',
///   onAction: (actionValue, actionName) {
///     print('Action triggered: $actionName with value: $actionValue');
///   },
///   onHeightChanged: (height) {
///     print('Native view height changed to: $height logical pixels');
///   },
/// )
/// ```
class InlineInAppMessageView extends StatefulWidget {
  /// Creates an inline in-app message view.
  ///
  /// [elementId] is required and identifies which message to display.
  /// [onAction] is an optional callback for handling message actions.
  /// [progressTint] is an optional color for the progress indicator.
  /// [onHeightChanged] is an optional callback for handling height changes.
  const InlineInAppMessageView({
    super.key,
    required this.elementId,
    this.onAction,
    this.progressTint,
    this.onHeightChanged,
  });

  /// The element ID that identifies which message to display
  final String elementId;

  /// Callback function that gets called when a message action is triggered
  final InAppMessageActionCallback? onAction;

  /// Optional color for the progress indicator
  final Color? progressTint;

  /// Optional callback for handling height changes in the native view
  final HeightChangeCallback? onHeightChanged;

  @override
  State<InlineInAppMessageView> createState() => _InlineInAppMessageViewState();
}

class _InlineInAppMessageViewState extends State<InlineInAppMessageView> 
    with SingleTickerProviderStateMixin {
  MethodChannel? _methodChannel;
  double? _nativeHeight;
  double? _nativeWidth;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _widthAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _methodChannel?.setMethodCallHandler(null);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'elementId': widget.elementId,
      if (widget.progressTint != null) 'progressTint': _colorToArgb(widget.progressTint!),
    };

    Widget platformView;

    if (defaultTargetPlatform == TargetPlatform.android) {
      platformView = AndroidView(
        viewType: 'customer_io_inline_in_app_message_view',
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<TapGestureRecognizer>(() => TapGestureRecognizer()
            ..onTap = () {
              if (kDebugMode) {
                debugPrint('InlineInAppMessageView: TapGestureRecognizer triggered');
              }
            }),
          Factory<PanGestureRecognizer>(() => PanGestureRecognizer()
            ..onStart = (details) {
              if (kDebugMode) {
                debugPrint('InlineInAppMessageView: PanGestureRecognizer started at ${details.localPosition}');
              }
            }),
          Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()
            ..onStart = (details) {
              if (kDebugMode) {
                debugPrint('InlineInAppMessageView: ScaleGestureRecognizer started at ${details.localFocalPoint}');
              }
            }),
        }.toSet(),
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: _nativeHeight ?? _heightAnimation.value,
          width: _nativeWidth ?? (_widthAnimation.value > 0 ? _widthAnimation.value : null),
          child: platformView,
        );
      },
    );
  }

  void _onPlatformViewCreated(int id) {
    if (kDebugMode) {
      debugPrint('InlineInAppMessageView: Platform view created with id: $id');
    }
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
        final duration = arguments['duration'] as double? ?? 200.0;
        
        if (mounted) {
          _animateToSize(width: width, height: height, duration: duration.toInt());
        }
        break;
      case 'onStateChange':
        final arguments = call.arguments as Map<dynamic, dynamic>;
        final state = arguments['state'] as String;
        
        if (mounted) {
          setState(() {
            _isLoading = state == 'LoadingStarted';
          });
          
          if (state == 'NoMessageToDisplay') {
            _animateToSize(height: 1.0, duration: 200);
          }
        }
        break;
    }
  }

  void _animateToSize({double? width, double? height, int duration = 200}) {
    _animationController.duration = Duration(milliseconds: duration);
    
    if (height != null) {
      final currentHeight = _nativeHeight ?? _heightAnimation.value;
      _heightAnimation = Tween<double>(
        begin: currentHeight,
        end: height,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
      
      _nativeHeight = height;
      widget.onHeightChanged?.call(height);
    }
    
    if (width != null) {
      final currentWidth = _nativeWidth ?? _widthAnimation.value;
      _widthAnimation = Tween<double>(
        begin: currentWidth,
        end: width,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
      
      _nativeWidth = width;
    }
    
    _animationController.forward(from: 0.0);
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
    await _safeInvokeMethod('setProgressTint', _colorToArgb(color));
  }

  /// Gets the current element ID from the native view
  Future<String?> getElementId() async {
    return await _safeInvokeMethod<String>('getElementId');
  }

  /// Converts a Flutter Color to ARGB integer format for native platform
  int _colorToArgb(Color color) {
    return ((color.a * 255).round() << 24) | 
           ((color.r * 255).round() << 16) | 
           ((color.g * 255).round() << 8) | 
           (color.b * 255).round();
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