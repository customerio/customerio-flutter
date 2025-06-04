import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_io/customer_io_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView', () {
    late List<MethodCall> methodCalls;
    late MethodChannel methodChannel;

    setUp(() {
      methodCalls = [];
      
      // Mock the method channel for platform view communication
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('customer_io_inline_view_0'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);
          
          // Mock responses for specific methods
          switch (methodCall.method) {
            case 'getElementId':
              return 'test-element';
            case 'setElementId':
            case 'setProgressTint':
              return null;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      // Clean up method channel mocks
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('customer_io_inline_view_0'),
        null,
      );
    });

    group('Widget Creation', () {
      testWidgets('creates widget with required elementId', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
              ),
            ),
          ),
        );

        expect(find.byType(InlineInAppMessageView), findsOneWidget);
      });

      testWidgets('creates widget with optional parameters', (WidgetTester tester) async {
        bool actionCalled = false;
        String? receivedActionValue;
        String? receivedActionName;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
                progressTint: Colors.blue,
                onAction: (actionValue, actionName, {messageId, deliveryId}) {
                  actionCalled = true;
                  receivedActionValue = actionValue;
                  receivedActionName = actionName;
                },
              ),
            ),
          ),
        );

        expect(find.byType(InlineInAppMessageView), findsOneWidget);
      });
    });

    group('Platform Specific Rendering', () {
      testWidgets('renders AndroidView on Android platform', (WidgetTester tester) async {
        // Override platform to Android for this test
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
              ),
            ),
          ),
        );

        expect(find.byType(AndroidView), findsOneWidget);
        
        // Reset platform override
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('renders empty Container on non-Android platforms', (WidgetTester tester) async {
        // Override platform to iOS for this test
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
              ),
            ),
          ),
        );

        expect(find.byType(AndroidView), findsNothing);
        expect(find.byType(Container), findsOneWidget);
        
        // Reset platform override
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Creation Parameters', () {
      testWidgets('passes correct creation parameters to AndroidView', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element-id',
                progressTint: const Color(0xFF123456),
              ),
            ),
          ),
        );

        final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
        
        expect(androidView.viewType, equals('customer_io_inline_in_app_message_view'));
        expect(androidView.creationParams, isA<Map<String, dynamic>>());
        
        final params = androidView.creationParams as Map<String, dynamic>;
        expect(params['elementId'], equals('test-element-id'));
        expect(params['progressTint'], equals(0xFF123456));

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('omits progressTint when not provided', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element-id',
              ),
            ),
          ),
        );

        final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
        final params = androidView.creationParams as Map<String, dynamic>;
        
        expect(params['elementId'], equals('test-element-id'));
        expect(params.containsKey('progressTint'), isFalse);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Action Handling', () {
      testWidgets('handles action callbacks correctly', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        
        bool actionCalled = false;
        String? receivedActionValue;
        String? receivedActionName;
        String? receivedMessageId;
        String? receivedDeliveryId;

        final widget = InlineInAppMessageView(
          elementId: 'test-banner',
          onAction: (actionValue, actionName, {messageId, deliveryId}) {
            actionCalled = true;
            receivedActionValue = actionValue;
            receivedActionName = actionName;
            receivedMessageId = messageId;
            receivedDeliveryId = deliveryId;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: widget),
          ),
        );

        // Get the widget state to test the method call handler
        final state = tester.state<_InlineInAppMessageViewState>(
          find.byType(InlineInAppMessageView),
        );

        // Simulate an action method call from the platform
        await state._handleMethodCall(
          const MethodCall('onAction', {
            'actionValue': 'test-value',
            'actionName': 'test-action',
            'messageId': 'msg-123',
            'deliveryId': 'del-456',
          }),
        );

        expect(actionCalled, isTrue);
        expect(receivedActionValue, equals('test-value'));
        expect(receivedActionName, equals('test-action'));
        expect(receivedMessageId, equals('msg-123'));
        expect(receivedDeliveryId, equals('del-456'));

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('handles action callbacks without optional parameters', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        
        bool actionCalled = false;
        String? receivedActionValue;
        String? receivedActionName;

        final widget = InlineInAppMessageView(
          elementId: 'test-banner',
          onAction: (actionValue, actionName, {messageId, deliveryId}) {
            actionCalled = true;
            receivedActionValue = actionValue;
            receivedActionName = actionName;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: widget),
          ),
        );

        final state = tester.state<_InlineInAppMessageViewState>(
          find.byType(InlineInAppMessageView),
        );

        // Simulate an action method call with null optional parameters
        await state._handleMethodCall(
          const MethodCall('onAction', {
            'actionValue': 'test-value',
            'actionName': 'test-action',
            'messageId': null,
            'deliveryId': null,
          }),
        );

        expect(actionCalled, isTrue);
        expect(receivedActionValue, equals('test-value'));
        expect(receivedActionName, equals('test-action'));

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('ignores actions when no callback provided', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
                // No onAction callback provided
              ),
            ),
          ),
        );

        final state = tester.state<_InlineInAppMessageViewState>(
          find.byType(InlineInAppMessageView),
        );

        // This should not throw an exception
        await state._handleMethodCall(
          const MethodCall('onAction', {
            'actionValue': 'test-value',
            'actionName': 'test-action',
          }),
        );

        // Test passes if no exception is thrown
        expect(true, isTrue);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Widget Updates', () {
      testWidgets('updates elementId when widget changes', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'initial-element',
              ),
            ),
          ),
        );

        // Update the widget with a new elementId
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'updated-element',
              ),
            ),
          ),
        );

        await tester.pump();

        // Verify setElementId was called with the new value
        expect(
          methodCalls.any((call) => 
            call.method == 'setElementId' && 
            call.arguments == 'updated-element'
          ),
          isTrue,
        );

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('updates progressTint when widget changes', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
                progressTint: Colors.red,
              ),
            ),
          ),
        );

        // Update the widget with a new progressTint
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
                progressTint: Colors.blue,
              ),
            ),
          ),
        );

        await tester.pump();

        // Verify setProgressTint was called with the new value
        expect(
          methodCalls.any((call) => 
            call.method == 'setProgressTint' && 
            call.arguments == Colors.blue.value
          ),
          isTrue,
        );

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Method Channel Communication', () {
      testWidgets('getElementId calls platform method', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
              ),
            ),
          ),
        );

        final state = tester.state<_InlineInAppMessageViewState>(
          find.byType(InlineInAppMessageView),
        );

        final result = await state.getElementId();
        
        expect(result, equals('test-element'));
        expect(
          methodCalls.any((call) => call.method == 'getElementId'),
          isTrue,
        );

        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}