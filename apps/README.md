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

## iOS 27 / UIScene lifecycle fixture (MBL-2232)

Using the Flutter **3.44.8** pins owned by MBL-2280, both samples bootstrap
their plugins from the implicit engine, via
`FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine(_:)`. That is
the one plugin-consumer seat in each app; the `FlutterAppDelegate` and
`FlutterSceneDelegate` super calls are raw/forward seats only.

Each sample ships two immutable Info.plist configurations. Nothing is edited to
switch between them — the Runner target resolves
`Runner/Info$(CIO_LIFECYCLE_INFOPLIST_SUFFIX).plist`, and the suffix is passed on
the xcodebuild command line:

| Configuration | Info.plist | Lifecycle |
|---|---|---|
| `legacy` (default) | `Runner/Info.plist` | `UIApplicationDelegate` |
| `scene` | `Runner/Info-Scene.plist` | `UIApplicationSceneManifest` → fixture subclass of `FlutterSceneDelegate` |

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./apps/scripts/lifecycle_fixture_build.sh legacy spm
./apps/scripts/lifecycle_fixture_build.sh scene  spm
./apps/scripts/lifecycle_fixture_build.sh legacy cocoapods
./apps/scripts/lifecycle_fixture_build.sh scene  cocoapods
```

The script refuses to run on a toolchain other than the pinned one and verifies
that the built product carries the configuration that was requested.

To check that the bootstrap still registers exactly once per implicit engine:

```bash
python3 apps/scripts/verify_implicit_engine_registration.py \
  --flutter-root "$(dirname "$(dirname "$(which flutter)")")" \
  --app <derived-data>/Build/Products/Debug-iphonesimulator/Runner.app
```

`apps/lifecycle_fixture/plugin-consumer-seats.lock.json` maps each Dart-side
receipt (Firebase, local notification, quick action, router) to a canonical
`cio-lifecycle-trace/1` callback and to the exact pinned plugin source that
delivers it. Resolve both samples with the same disposable `PUB_CACHE` before
running `flutter test test/ios27_lifecycle`; the tests fail closed if either
sample resolution is absent, then re-derive every digest from that cache.

See `docs/mbl-2232-flutter-lifecycle-fixture.md` for the vendored contract,
scope, verification commands, and evidence status.
