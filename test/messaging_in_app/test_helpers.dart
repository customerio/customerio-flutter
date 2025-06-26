import 'package:customer_io/messaging_in_app/inline_in_app_message_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test helper utilities for messaging in-app tests
class TestHelpers {
  TestHelpers._(); // Prevent instantiation

  /// Wrapper for testWidgets that automatically handles platform override cleanup
  static void testWidgetsWithPlatform(
    String description,
    TargetPlatform platform,
    WidgetTesterCallback callback, {
    bool? skip,
    Timeout? timeout,
    bool semanticsEnabled = true,
    TestVariant<Object?> variant = const DefaultTestVariant(),
    dynamic tags,
  }) {
    testWidgets(
      description,
      (WidgetTester tester) async {
        // Set platform override
        debugDefaultTargetPlatformOverride = platform;
        
        try {
          // Run the actual test
          await callback(tester);
        } finally {
          // Always cleanup, even if test throws
          debugDefaultTargetPlatformOverride = null;
        }
      },
      skip: skip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: variant,
      tags: tags,
    );
  }

  /// Helper to find SizedBox within InlineInAppMessageView widget tree
  static Finder findSizedBoxInInlineView() {
    final inlineView = find.byType(InlineInAppMessageView);
    final animatedSize = find.descendant(
      of: inlineView,
      matching: find.byType(AnimatedSize),
    );
    return find.descendant(
      of: animatedSize,
      matching: find.byType(SizedBox),
    );
  }

  /// Helper to get the SizedBox widget from InlineInAppMessageView
  static SizedBox getSizedBoxFromInlineView(WidgetTester tester) {
    final sizedBoxes = findSizedBoxInInlineView();
    return tester.widget<SizedBox>(sizedBoxes.first);
  }
}