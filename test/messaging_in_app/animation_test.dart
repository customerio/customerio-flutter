import 'package:customer_io/customer_io_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InlineInAppMessageView Animation', () {
    testWidgets('widget has initial animation state', (WidgetTester tester) async {
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

      // Verify widget is created with AnimatedBuilder
      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsWidgets);
      expect(find.byType(SizedBox), findsWidgets);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget responds to size change animations', (WidgetTester tester) async {
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
        'duration': 200.0,
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      // Pump to start the animation
      await tester.pump();

      // Fast-forward the animation
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the widget still exists and has been updated
      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);

      final updatedSizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      
      // The height should be updated to the new size
      expect(updatedSizedBox.height, equals(200.0));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles width-only size changes', (WidgetTester tester) async {
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

      // Simulate width-only change
      const String channelName = 'customer_io_inline_view_123';
      const sizeArguments = {
        'width': 250.0,
        'duration': 150.0,
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles height-only size changes', (WidgetTester tester) async {
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

      // Simulate height-only change
      const String channelName = 'customer_io_inline_view_123';
      const sizeArguments = {
        'height': 100.0,
        'duration': 300.0,
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, equals(100.0));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles NoMessageToDisplay state animation', (WidgetTester tester) async {
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

      // Simulate NoMessageToDisplay state
      const String channelName = 'customer_io_inline_view_123';
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onStateChange', {'state': 'NoMessageToDisplay'}),
        ),
        (data) {},
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify widget still exists and has minimal height
      expect(find.byType(InlineInAppMessageView), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, equals(1.0));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles multiple rapid size changes', (WidgetTester tester) async {
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

      // Send multiple rapid size changes
      for (int i = 0; i < 3; i++) {
        final sizeArguments = {
          'height': 50.0 + (i * 25),
          'width': 200.0 + (i * 50),
          'duration': 100.0,
        };

        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('onSizeChange', sizeArguments),
          ),
          (data) {},
        );

        await tester.pump(const Duration(milliseconds: 50));
      }

      // Allow final animation to complete
      await tester.pump(const Duration(milliseconds: 100));

      // Verify widget still functions properly
      expect(find.byType(InlineInAppMessageView), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget animation respects custom duration', (WidgetTester tester) async {
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

      // Test custom duration
      const String channelName = 'customer_io_inline_view_123';
      const sizeArguments = {
        'height': 150.0,
        'duration': 500.0, // Custom duration
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      await tester.pump();

      // Animation should not be complete after 250ms (half duration)
      await tester.pump(const Duration(milliseconds: 250));
      
      // Complete the animation
      await tester.pump(const Duration(milliseconds: 250));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, equals(150.0));

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('widget handles size changes without duration parameter', (WidgetTester tester) async {
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

      // Test without duration (should default to 200ms)
      const String channelName = 'customer_io_inline_view_123';
      const sizeArguments = {
        'height': 120.0,
        'width': 280.0,
      };

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onSizeChange', sizeArguments),
        ),
        (data) {},
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // Default duration

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, equals(120.0));

      debugDefaultTargetPlatformOverride = null;
    });
  });
}