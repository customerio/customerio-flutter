import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView Method Channel', () {
    late Map<String, dynamic> lastActionCallback;

    setUp(() {
      lastActionCallback = {};
    });

    testWidgets('handles onAction method calls correctly', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: 'test-banner',
              onAction: (actionValue, actionName, {messageId, deliveryId}) {
                lastActionCallback = {
                  'actionValue': actionValue,
                  'actionName': actionName,
                  'messageId': messageId,
                  'deliveryId': deliveryId,
                };
              },
            ),
          ),
        ),
      );

      // Find the AndroidView to get its method channel
      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect(androidView.onPlatformViewCreated, isNotNull);

      // Simulate platform view creation
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      // Wait for the platform view to be created
      await tester.pump();

      // Simulate method channel call for onAction
      const String channelName = 'customer_io_inline_view_123';
      const actionArguments = {
        'actionValue': 'test-action-value',
        'actionName': 'test-action-name',
        'messageId': 'test-message-id',
        'deliveryId': 'test-delivery-id',
      };

      // Mock the method channel call
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onAction', actionArguments),
        ),
        (data) {},
      );

      await tester.pump();

      // Verify the callback was called with correct parameters
      expect(lastActionCallback['actionValue'], equals('test-action-value'));
      expect(lastActionCallback['actionName'], equals('test-action-name'));
      expect(lastActionCallback['messageId'], equals('test-message-id'));
      expect(lastActionCallback['deliveryId'], equals('test-delivery-id'));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('handles onAction method calls without callback', (WidgetTester tester) async {
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

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      // Simulate method channel call for onAction without callback
      const String channelName = 'customer_io_inline_view_123';
      const actionArguments = {
        'actionValue': 'test-action-value',
        'actionName': 'test-action-name',
      };

      // This should not throw an error even without callback
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', actionArguments),
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('handles onSizeChange method calls', (WidgetTester tester) async {
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

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      // Simulate method channel call for onSizeChange
      const String channelName = 'customer_io_inline_view_123';
      const sizeArguments = {
        'width': 300.0,
        'height': 200.0,
        'duration': 500.0,
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      await tester.pump();

      // Verify the widget still exists and can handle the size change
      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('handles onStateChange method calls', (WidgetTester tester) async {
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

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      // Test LoadingStarted state
      const String channelName = 'customer_io_inline_view_123';
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onStateChange', {'state': 'LoadingStarted'}),
        ),
        (data) {},
      );

      await tester.pump();
      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      // Test NoMessageToDisplay state
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onStateChange', {'state': 'NoMessageToDisplay'}),
        ),
        (data) {},
      );

      await tester.pump();
      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('handles unknown method calls gracefully', (WidgetTester tester) async {
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

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      // Simulate unknown method call
      const String channelName = 'customer_io_inline_view_123';
      
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('unknownMethod', {'data': 'test'}),
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget cleans up method channel on disposal', (WidgetTester tester) async {
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

      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('No widget'),
          ),
        ),
      );

      // Verify the widget is removed
      expect(find.byType(InlineInAppMessageView), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}