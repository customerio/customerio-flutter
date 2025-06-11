import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView', () {
    group('Widget Creation', () {
      testWidgets('creates widget with required elementId', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
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
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
                progressTint: Colors.blue,
                onAction: (actionValue, actionName, {messageId, deliveryId}) {
                  // Action handler for testing
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
          const MaterialApp(
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

      testWidgets('renders UiKitView on iOS platform', (WidgetTester tester) async {
        // Override platform to iOS for this test
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
              ),
            ),
          ),
        );

        expect(find.byType(UiKitView), findsOneWidget);
        
        // Reset platform override
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('renders empty widget on unsupported platforms', (WidgetTester tester) async {
        // Override platform to web for this test
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
              ),
            ),
          ),
        );

        expect(find.byType(AndroidView), findsNothing);
        expect(find.byType(UiKitView), findsNothing);
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        
        // Reset platform override
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Creation Parameters', () {
      testWidgets('passes correct creation parameters to AndroidView', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element-id',
                progressTint: Color(0xFF123456),
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

      testWidgets('passes correct creation parameters to UiKitView', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element-id',
                progressTint: Color(0xFF123456),
              ),
            ),
          ),
        );

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        
        expect(uiKitView.viewType, equals('customer_io_inline_in_app_message_view'));
        expect(uiKitView.creationParams, isA<Map<String, dynamic>>());
        
        final params = uiKitView.creationParams as Map<String, dynamic>;
        expect(params['elementId'], equals('test-element-id'));
        expect(params['progressTint'], equals(0xFF123456));

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('omits progressTint when not provided', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
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
      testWidgets('widget accepts action callback parameter', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
                onAction: (actionValue, actionName, {messageId, deliveryId}) {
                  // Action handler for testing
                },
              ),
            ),
          ),
        );

        // Verify widget was created with callback
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(find.byType(AndroidView), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('widget works without action callback', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-banner',
                // No onAction callback provided
              ),
            ),
          ),
        );

        // Verify widget was created without issues
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(find.byType(AndroidView), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Widget Updates', () {
      testWidgets('widget rebuilds correctly when elementId changes', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'initial-element',
              ),
            ),
          ),
        );

        // Verify initial widget creation
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(find.byType(AndroidView), findsOneWidget);

        // Update the widget with a new elementId
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'updated-element',
              ),
            ),
          ),
        );

        await tester.pump();

        // Verify widget still exists after update
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(find.byType(AndroidView), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('widget rebuilds correctly when progressTint changes', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
                progressTint: Colors.red,
              ),
            ),
          ),
        );

        // Verify initial widget creation
        expect(find.byType(InlineInAppMessageView), findsOneWidget);

        // Update the widget with a new progressTint
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
                progressTint: Colors.blue,
              ),
            ),
          ),
        );

        await tester.pump();

        // Verify widget still exists after update
        expect(find.byType(InlineInAppMessageView), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('Platform View Integration', () {
      testWidgets('widget handles platform view creation callback', (WidgetTester tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: 'test-element',
              ),
            ),
          ),
        );

        // Verify widget was created successfully
        expect(find.byType(InlineInAppMessageView), findsOneWidget);
        expect(find.byType(AndroidView), findsOneWidget);

        // Verify that the AndroidView has the correct configuration
        final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
        expect(androidView.onPlatformViewCreated, isNotNull);
        expect(androidView.viewType, equals('customer_io_inline_in_app_message_view'));

        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}