import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView Error Handling', () {
    testWidgets('widget handles malformed onAction arguments gracefully',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: 'test-banner',
              onActionClick: (message, actionValue, actionName) {
                // Test callback
              },
            ),
          ),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      const String channelName = 'customer_io_inline_view_123';

      // Test with missing required arguments
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
                'onAction', {'actionValue': 'test'}), // Missing actionName
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with null arguments
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', null),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with wrong type arguments
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', {
              'actionValue': 123, // Should be string
              'actionName': 456, // Should be string
            }),
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles malformed onSizeChange arguments gracefully',
        (WidgetTester tester) async {
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

      const String channelName = 'customer_io_inline_view_123';

      // Test with invalid width/height types
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', {
              'width': 'invalid', // Should be number
              'height': 'invalid', // Should be number
              'duration': 'invalid', // Should be number
            }),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with null arguments
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', null),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with negative values
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', {
              'width': -100.0,
              'height': -50.0,
              'duration': -200.0,
            }),
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles malformed onStateChange arguments gracefully',
        (WidgetTester tester) async {
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

      const String channelName = 'customer_io_inline_view_123';

      // Test with missing state argument
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onStateChange', {}),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with null arguments
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onStateChange', null),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Test with wrong type state
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(
                'onStateChange', {'state': 123}), // Should be string
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles method calls when not mounted',
        (WidgetTester tester) async {
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

      // Remove the widget (unmount it)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Different widget'),
          ),
        ),
      );

      const String channelName = 'customer_io_inline_view_123';

      // Try to send method calls when widget is unmounted - should not crash
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSizeChange', {
              'width': 100.0,
              'height': 100.0,
            }),
          ),
          (data) {},
        );
      }, returnsNormally);

      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onStateChange', {'state': 'LoadingStarted'}),
          ),
          (data) {},
        );
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles empty or invalid element IDs',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      // Test with empty string
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: '',
            ),
          ),
        ),
      );

      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AndroidView), findsOneWidget);

      // Test with very long element ID
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: 'a' * 1000, // Very long string
            ),
          ),
        ),
      );

      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AndroidView), findsOneWidget);

      // Test with special characters
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: '!@#\$%^&*()_+{}|:<>?[],./',
            ),
          ),
        ),
      );

      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AndroidView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles disposal during method channel setup',
        (WidgetTester tester) async {
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

      // Immediately remove the widget after finding it but before platform view setup
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Different widget'),
          ),
        ),
      );

      // Try to create platform view after widget is disposed - should not crash
      expect(() {
        androidView.onPlatformViewCreated!(123);
      }, returnsNormally);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles rapid elementId changes',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      String currentElementId = 'initial-element';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: currentElementId,
            ),
          ),
        ),
      );

      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      // Rapidly change element IDs
      for (int i = 0; i < 10; i++) {
        currentElementId = 'element-$i';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InlineInAppMessageView(
                elementId: currentElementId,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      // Widget should still be functional
      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AndroidView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles callback exceptions gracefully',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineInAppMessageView(
              elementId: 'test-banner',
              onActionClick: (message, actionValue, actionName) {
                // Simulate an exception in the callback
                throw Exception('Test exception in callback');
              },
            ),
          ),
        ),
      );

      final androidView = tester.widget<AndroidView>(find.byType(AndroidView));
      const int platformViewId = 123;
      androidView.onPlatformViewCreated!(platformViewId);

      await tester.pump();

      const String channelName = 'customer_io_inline_view_123';

      // The widget should handle callback exceptions gracefully
      expect(() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onAction', {
              'actionValue': 'test-action-value',
              'actionName': 'test-action-name',
            }),
          ),
          (data) {},
        );
      }, returnsNormally);

      // Widget should still be functional
      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
