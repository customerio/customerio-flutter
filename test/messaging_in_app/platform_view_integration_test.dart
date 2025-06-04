import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform View Integration', () {
    testWidgets('InlineInAppMessageView integrates with platform view registry',
        (WidgetTester tester) async {
      // This test verifies that the widget can be created and rendered
      // without throwing platform view registration errors
      
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      // Create the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Test App'),
                SizedBox(
                  height: 200,
                  child: InlineInAppMessageView(
                    elementId: 'integration-test-banner',
                    onAction: (actionValue, actionName, {messageId, deliveryId}) {
                      // Action handler for testing
                      debugPrint('Action: $actionName = $actionValue');
                    },
                    progressTint: Colors.purple,
                  ),
                ),
                const Text('End of Test'),
              ],
            ),
          ),
        ),
      );

      // Verify the widget tree is built correctly
      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('End of Test'), findsOneWidget);
      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AndroidView), findsOneWidget);

      // Verify AndroidView has correct configuration
      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(androidView.viewType, equals('customer_io_inline_in_app_message_view'));
      
      final params = androidView.creationParams as Map<String, dynamic>;
      expect(params['elementId'], equals('integration-test-banner'));
      expect(params['progressTint'], equals(Colors.purple.toARGB32()));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Multiple InlineInAppMessageView widgets can coexist',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: InlineInAppMessageView(
                    elementId: 'banner-1',
                    progressTint: Colors.red,
                  ),
                ),
                Expanded(
                  child: InlineInAppMessageView(
                    elementId: 'banner-2',
                    progressTint: Colors.blue,
                  ),
                ),
                Expanded(
                  child: InlineInAppMessageView(
                    elementId: 'banner-3',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify all widgets are rendered
      expect(find.byType(InlineInAppMessageView), findsNWidgets(3));
      expect(find.byType(AndroidView), findsNWidgets(3));

      // Verify each has unique element IDs
      final androidViews = tester.widgetList<AndroidView>(find.byType(AndroidView));
      final elementIds = androidViews.map((view) {
        final params = view.creationParams as Map<String, dynamic>;
        return params['elementId'];
      }).toList();

      expect(elementIds, containsAll(['banner-1', 'banner-2', 'banner-3']));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Widget handles platform view creation callback',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: 'callback-test-banner',
            ),
          ),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      
      // Verify that onPlatformViewCreated callback is set
      expect(androidView.onPlatformViewCreated, isNotNull);

      // Simulate platform view creation (this would normally be called by the platform)
      // Note: In a real test environment, we can't easily mock this without more setup
      // but we can verify the callback is properly configured
      
      debugDefaultTargetPlatformOverride = null;
    });
  });
}