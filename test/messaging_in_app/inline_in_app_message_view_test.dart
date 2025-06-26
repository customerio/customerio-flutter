import 'package:customer_io/messaging_in_app/inline_in_app_message_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView', () {
    setUp(() {
      // Setup test environment
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    group('Widget Creation', () {
      testWidgets('creates widget with required elementId',
          (WidgetTester tester) async {
        const elementId = 'test-element';

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: elementId),
          ),
        );

        expect(find.byType(InlineInAppMessageView), findsOneWidget);
      });

      testWidgets('accepts optional onActionClick callback',
          (WidgetTester tester) async {
        const elementId = 'test-element';
        bool callbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: InlineInAppMessageView(
              elementId: elementId,
              onActionClick: (message, actionValue, actionName) {
                callbackCalled = true;
              },
            ),
          ),
        );

        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(callbackCalled, false); // Should not be called during creation
      });
    });

    group('Platform-Specific Rendering', () {
      testWidgets('renders AndroidView on Android platform',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        expect(find.byType(AndroidView), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('renders UiKitView on iOS platform',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        expect(find.byType(UiKitView), findsOneWidget);
        expect(find.byType(AndroidView), findsNothing);
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('renders empty widget on unsupported platforms',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        expect(find.byType(AndroidView), findsNothing);
        expect(find.byType(UiKitView), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);
        
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Platform View Configuration', () {
      testWidgets('passes correct creation parameters to AndroidView',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const elementId = 'test-element-android';

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: elementId),
          ),
        );

        final androidView =
            tester.widget<AndroidView>(find.byType(AndroidView));
        expect(androidView.viewType, 'customer_io_inline_in_app_message_view');
        expect(androidView.creationParams, {'elementId': elementId});
        expect(androidView.layoutDirection, TextDirection.ltr);
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('passes correct creation parameters to UiKitView',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        const elementId = 'test-element-ios';

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: elementId),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(uiKitView.viewType, 'customer_io_inline_in_app_message_view');
        expect(uiKitView.creationParams, {'elementId': elementId});
        
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Method Channel Communication', () {
      testWidgets('sets up method channel on platform view creation',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));

        // Simulate platform view creation
        if (uiKitView.onPlatformViewCreated != null) {
          uiKitView.onPlatformViewCreated!(123);
        }

        // Method channel should be set up at this point
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles onActionClick method calls correctly',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        String? receivedActionValue;
        String? receivedActionName;
        InAppMessage? receivedMessage;

        await tester.pumpWidget(
          MaterialApp(
            home: InlineInAppMessageView(
              elementId: 'test-element',
              onActionClick: (message, actionValue, actionName) {
                receivedMessage = message;
                receivedActionValue = actionValue;
                receivedActionName = actionName;
              },
            ),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        // Simulate native method call
        const channelName = 'customer_io_inline_view_123';
        const actionArgs = {
          'actionValue': 'test-action-value',
          'actionName': 'test-action-name',
          'messageId': 'test-message-id',
          'deliveryId': 'test-delivery-id',
        };

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', actionArgs),
          ),
          (data) {},
        );

        expect(receivedActionValue, 'test-action-value');
        expect(receivedActionName, 'test-action-name');
        expect(receivedMessage?.messageId, 'test-message-id');
        expect(receivedMessage?.deliveryId, 'test-delivery-id');
        expect(receivedMessage?.elementId, 'test-element');
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles onSizeChange method calls correctly',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';
        const sizeArgs = {
          'width': 300.0,
          'height': 150.0,
        };

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', sizeArgs),
          ),
          (data) {},
        );

        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        // Verify that the widget updated its size
        final inlineView = find.byType(InlineInAppMessageView);
        final animatedSize = find.descendant(
          of: inlineView,
          matching: find.byType(AnimatedSize),
        );
        final sizedBoxes = find.descendant(
          of: animatedSize,
          matching: find.byType(SizedBox),
        );
        final sizedBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(sizedBox.height, 150.0);
        expect(sizedBox.width, 300.0);
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles zero height in onSizeChange correctly',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';
        const sizeArgs = {
          'width': 300.0,
          'height': 0.0, // Zero height should be converted to 1.0
        };

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', sizeArgs),
          ),
          (data) {},
        );

        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        final inlineView = find.byType(InlineInAppMessageView);
        final animatedSize = find.descendant(
          of: inlineView,
          matching: find.byType(AnimatedSize),
        );
        final sizedBoxes = find.descendant(
          of: animatedSize,
          matching: find.byType(SizedBox),
        );
        final sizedBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(sizedBox.height, 1.0); // Should be converted from 0.0 to 1.0
        expect(sizedBox.width, 300.0);
      });

      testWidgets('handles onStateChange with NoMessageToDisplay correctly',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';
        const stateArgs = {
          'state': 'NoMessageToDisplay',
        };

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onStateChange', stateArgs),
          ),
          (data) {},
        );

        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        final inlineView = find.byType(InlineInAppMessageView);
        final animatedSize = find.descendant(
          of: inlineView,
          matching: find.byType(AnimatedSize),
        );
        final sizedBoxes = find.descendant(
          of: animatedSize,
          matching: find.byType(SizedBox),
        );
        final sizedBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(sizedBox.height, 1.0); // Should be set to fallback height
      });
    });

    group('Widget Lifecycle', () {
      testWidgets('calls cleanup on dispose', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        // Track method calls to the platform
        const channelName = 'customer_io_inline_view_123';
        bool cleanupCalled = false;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (MethodCall methodCall) async {
            if (methodCall.method == 'cleanup') {
              cleanupCalled = true;
            }
            return null;
          },
        );

        // Remove the widget to trigger dispose
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(cleanupCalled, true);
      });

      testWidgets('updates elementId when widget is updated',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'initial-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';
        String? setElementIdValue;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(channelName),
          (MethodCall methodCall) async {
            if (methodCall.method == 'setElementId') {
              setElementIdValue = methodCall.arguments as String;
            }
            return null;
          },
        );

        // Update the widget with new elementId
        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'updated-element'),
          ),
        );

        expect(setElementIdValue, 'updated-element');
      });
    });

    group('Error Handling', () {
      testWidgets('handles missing arguments gracefully',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';

        // Send method call with missing arguments
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', null),
          ),
          (data) {},
        );

        // Should not crash
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles unknown method calls gracefully',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';

        // Send unknown method call
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('unknownMethod', {}),
          ),
          (data) {},
        );

        // Should not crash
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles onAction without callback gracefully',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
            // No onActionClick callback provided
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        uiKitView.onPlatformViewCreated!(123);
        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;

        const channelName = 'customer_io_inline_view_123';
        const actionArgs = {
          'actionValue': 'test-action-value',
          'actionName': 'test-action-name',
        };

        // Should not crash when no callback is provided
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', actionArgs),
          ),
          (data) {},
        );

        await tester.pump();
        
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Animation and Layout', () {
      testWidgets('uses AnimatedSize for smooth transitions',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        expect(find.byType(AnimatedSize), findsOneWidget);

        final animatedSize =
            tester.widget<AnimatedSize>(find.byType(AnimatedSize));
        expect(animatedSize.duration, const Duration(milliseconds: 200));
        
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('starts with default height of 1.0',
          (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: InlineInAppMessageView(elementId: 'test-element'),
          ),
        );

        final inlineView = find.byType(InlineInAppMessageView);
        final animatedSize = find.descendant(
          of: inlineView,
          matching: find.byType(AnimatedSize),
        );
        final sizedBoxes = find.descendant(
          of: animatedSize,
          matching: find.byType(SizedBox),
        );
        final sizedBox = tester.widget<SizedBox>(sizedBoxes.first);
        expect(sizedBox.height, 1.0);
        expect(sizedBox.width, double.infinity);
        
        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}
