# Update Customer.io native SDKs

Update the Customer.io **iOS** and/or **Android** native SDK versions used by this Flutter plugin.

## Where versions are defined

| Platform | File | What to change |
|----------|------|----------------|
| **iOS** | `pubspec.yaml` | `flutter.plugin.platforms.ios.native_sdk_version` (and optionally `firebase_wrapper_version` if needed) |
| **Android** | `android/build.gradle` | `def cioVersion = "x.y.z"` |

- iOS version is read by `ios/customer_io.podspec` and `ios/customer_io_richpush.podspec` from `pubspec.yaml`.
- Android version is used in `android/build.gradle` for `io.customer.android:*` dependencies.

## Steps

1. **Decide target versions**
   - Check latest releases (optional):
     - iOS: https://github.com/customerio/customerio-ios/releases
     - Android: https://github.com/customerio/customerio-android/releases

2. **Update iOS native SDK**
   - In **`pubspec.yaml`**, under `flutter.plugin.platforms.ios`, set:
     - `native_sdk_version: <new version>` (e.g. `4.1.3`)
     - Only change `firebase_wrapper_version` if the iOS SDK or docs require it.

3. **Update Android native SDK**
   - In **`android/build.gradle`**, update the line:
     - `def cioVersion = "<new version>"` (e.g. `"4.15.2"`)

4. **Verify**
   - From repo root:
     - `flutter pub get`
     - `flutter pub get` in `apps/amiapp_flutter` (so the sample app uses the updated plugin)
     - `flutter analyze --no-fatal-infos`
     - `flutter test`
   - Optionally build the example/sample app (e.g. `apps/amiapp_flutter`) on iOS and Android to confirm native integration.
