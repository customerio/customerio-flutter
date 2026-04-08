# Sample Apps

Two sample apps for testing the Flutter SDK, differentiated by iOS dependency manager:

| App | Directory | Bundle ID (iOS) | Purpose |
|-----|-----------|----------------|---------|
| **SPM** (primary) | `flutter_sample_spm/` | `io.customer.testbed.flutter.spm` | Primary test app using SPM for iOS CIO SDK dependencies. |
| **CocoaPods** (secondary) | `flutter_sample_cocoapods/` | `io.customer.testbed.flutter.cocoapods` | Secondary test app using CocoaPods for iOS CIO SDK dependencies. |

## iOS Dependency Management

SPM vs CocoaPods is controlled per-project via `enable-swift-package-manager` in each app's `pubspec.yaml`. The NSE (NotificationServiceExtension) links `FlutterGeneratedPluginSwiftPackage` in the SPM app, and `customer_io_richpush/fcm` pod in the CocoaPods app.

## Shared Code

Dart source code under `lib/src/` is shared via symlink:
- `flutter_sample_spm/lib/src/` — actual source files
- `flutter_sample_cocoapods/lib/src/` — symlink to SPM app's `lib/src/`

Each app has its own `lib/main.dart`, `lib/firebase_options.dart`, native configs, and Fastlane setup.

**When adding new Dart code**, add it to the SPM app's `lib/src/`. It will automatically be available in the CocoaPods app via the symlink.

## Local Dev Setup

```bash
# 1. Setup environment files (creates .env + ios/Env.swift with dummy values)
./apps/scripts/setup_env.sh apps/flutter_sample_spm

# 2. Install dependencies
cd apps/flutter_sample_spm
flutter pub get

# 3. Build
flutter build ios --no-codesign   # iOS
flutter build apk                 # Android
```

Same steps for `flutter_sample_cocoapods/`. Update `.env` and `ios/Env.swift` with real workspace credentials to connect to a Customer.io workspace.

For a guided interactive walkthrough:
```bash
./apps/scripts/setup.sh apps/flutter_sample_spm
```

## CI

- **PRs and pushes**: both apps are built to verify SPM and CocoaPods compatibility
- **SDK releases**: only the primary app is built
