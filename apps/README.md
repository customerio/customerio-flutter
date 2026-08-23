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

### Xcode 27 Flutter toolchain

The Xcode 27 compile lane must use the exact Flutter version recorded in both
sample apps' `.flutter-version` files. Flutter `3.44.8` is the first stable
release containing the [upstream fix](https://github.com/flutter/flutter/pull/188625)
for Xcode 27 rejecting multi-architecture
`lipo -verify_arch` calls. The lane must run
`apps/scripts/verify_xcode27_flutter_version.sh` before installing Flutter and
run it again with `--installed` after setup, in the same `PATH` context used by
the subsequent Flutter build.

This pairing is an Xcode 27 build-tool requirement. It does not raise the
published `customer_io` package minimum of Flutter `2.5.0`. Any deliberate
older-Flutter compatibility check must remain on an appropriate older Xcode
lane and must not be represented as Xcode 27-compatible.

## iOS App Delegate Regression Check

Both samples register a `quick_actions` lifecycle delegate to verify that the
Customer.io app delegate wrapper preserves the wrapped Flutter app delegate's
Objective-C protocol conformance and forwarding behavior.

1. Launch the sample once so it registers the **Test Flutter lifecycle** Home
   Screen quick action.
2. Terminate the app, long-press its Home Screen icon, and select the action.
   Confirm the banner ends in `(1)`.
3. Press Home without terminating the app, select the action again, and confirm
   the same banner ends in `(2)`.

Run the check on both the SPM and CocoaPods samples whenever the native iOS SDK
pin or app delegate integration changes.

## UIScene sample configuration

Both samples keep AppDelegate-only behavior in `Runner/Info.plist` and provide an explicit UIScene
configuration in `Runner/Info-Scene.plist`. The Runner target selects the scene configuration when
`CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene` is passed to Xcode.

The standard Apple scene manifest is the lifecycle source of truth; no Customer.io-specific
topology key is required. `CioAppDelegateWrapper` continues to own SDK initialization, APNs
registration, and notification-center callbacks in both modes. The standard Flutter
`SceneDelegate` owns the host scene, while the Customer.io plugin registers its own scene adapter
with each supported Flutter engine. A custom scene delegate must provide the equivalent Flutter
scene lifecycle forwarding. Flutter requires manual registration only when multiple scenes are
enabled and the target engine is not represented by the scene's root `FlutterViewController`
during connection; the host scene delegate owns that scene-to-engine association. Do not add a
second Customer.io URL handler to the scene delegate. AppDelegate-only samples keep their existing
`application(_:open:options:)` handler unchanged.

When upgrading an existing UIScene app that manually calls
`CustomerIOLiveActivities.handleWidgetUrl`, remove that call before enabling the automatic scene
adapter to avoid reporting the same tap twice.

Automatic UIScene redirect delivery uses Flutter's standard deep-link handling. A scene host that
sets `FlutterDeepLinkingEnabled` to `false` keeps its existing lifecycle handler and resolves the
Customer.io tracking URL with `CustomerIOLiveActivities.handleWidgetUrl` before forwarding the
result to its custom router.

For a UIScene host with Flutter deep linking enabled, the plugin also registers the native
Customer.io `deepLinkCallback` during SDK initialization. This routes SDK-triggered push, in-app,
and inbox destinations through a foreground Flutter scene. If Flutter declines the destination or
no foreground engine becomes available, the plugin opens it with `UIApplication.open`.
AppDelegate-only hosts keep their existing handoff, and setting `FlutterDeepLinkingEnabled` to
`false` leaves routing with the host.
