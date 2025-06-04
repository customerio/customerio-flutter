# InlineInAppMessageView Tests

This directory contains tests for the `InlineInAppMessageView` Flutter widget and its platform integration.

## Test Files

### `inline_in_app_message_view_test.dart`
Unit tests for the InlineInAppMessageView widget covering:

- **Widget Creation**: Basic widget instantiation with required and optional parameters
- **Platform Specific Rendering**: Different behavior on Android vs other platforms
- **Creation Parameters**: Correct parameter passing to AndroidView
- **Action Handling**: Callback functionality and edge cases
- **Widget Updates**: Dynamic property changes (elementId, progressTint)
- **Method Channel Communication**: Platform method calls

### `platform_view_integration_test.dart`
Integration tests for platform view registration and multiple widget scenarios:

- **Platform View Integration**: Verifies widget integrates with Flutter's platform view registry
- **Multiple Widgets**: Tests multiple InlineInAppMessageView widgets coexisting
- **Callback Configuration**: Ensures platform view creation callbacks are properly set

## Running Tests

To run all tests in this directory:
```bash
flutter test test/messaging_in_app/
```

To run a specific test file:
```bash
flutter test test/messaging_in_app/inline_in_app_message_view_test.dart
```

To run tests with coverage:
```bash
flutter test --coverage test/messaging_in_app/
```

## Test Coverage

The tests cover:
- ✅ Widget creation and configuration
- ✅ Platform-specific rendering (Android vs iOS)
- ✅ Parameter passing to native platform
- ✅ Action callback handling
- ✅ Dynamic property updates
- ✅ Method channel communication
- ✅ Multiple widget instances
- ✅ Error handling and edge cases

## Mock Setup

Tests use Flutter's built-in testing framework with:
- `TestWidgetsFlutterBinding` for widget testing
- `MethodChannel` mocking for platform communication
- `debugDefaultTargetPlatformOverride` for platform-specific testing