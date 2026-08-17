<p align=center>
  <a href="https://customer.io">
    <img src="https://avatars.githubusercontent.com/u/1152079?s=200&v=4" height="60">
  </a>
</p>

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](CODE_OF_CONDUCT.md)

# Customer.io Flutter Plugin

This is the official Customer.io Flutter plugin. 

# Getting started 

You'll find our complete [SDK documentation here](https://customer.io/docs/sdk/flutter/). 

If a CocoaPods build reports that a generated dependency target is below the deployment range
supported by Xcode, follow the [deployment-target normalization guide](docs/cocoapods-deployment-target-normalization.md).

# Live Activities

Enable the activity types you use via `liveNotificationsConfig` in your `CustomerIOConfig`. On iOS, Live Activities are opt-in: add the `liveactivities` pod subspec (CocoaPods) or set `customerio_live_activities_enabled=true` in `android/gradle.properties` (Swift Package Manager), plus a Widget Extension that renders the SDK's built-in templates.

iOS also requires `NSSupportsLiveActivities` in `ios/Runner/Info.plist`. Without it the system refuses to start any activity, so nothing appears even when everything else is configured:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

For an activity of your own, set `customType` to your reverse-DNS identifier and start it with `LiveActivityPayload.custom(data: {...})`. You supply the view: `CIOCustomAttributes` in your iOS Widget Extension, and the `createLiveNotification` callback on Android.

**One manual step is required on iOS.** Forward every opened URL to the SDK from your `AppDelegate`, or taps on a Live Activity are not attributed. `CustomerIOLiveActivities` comes from the plugin, so import it — and note this only compiles once Live Activities are opted in above:

```swift
import customer_io

override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
  // Reports an `opened` metric and returns the deep link to route to. A non-Customer.io URL comes
  // back unchanged; `nil` means the activity carried no deep link, so there is nothing to open.
  guard let routableUrl = CustomerIOLiveActivities.handleWidgetUrl(url) else { return true }
  return super.application(app, open: routableUrl, options: options)
}
```

Apps with a `UIApplicationSceneManifest` receive opened URLs through their scene lifecycle instead
of the AppDelegate callback above. Register a `FlutterSceneLifeCycleDelegate` on every Flutter
engine registry and forward `scene(_:willConnectTo:options:)` plus
`scene(_:openURLContexts:)`. The
[SwiftPM sample](apps/flutter_sample_spm/ios/Runner/SceneDelegate.swift) and
[CocoaPods sample](apps/flutter_sample_cocoapods/ios/Runner/SceneDelegate.swift) show the complete
registration and routing pattern. The samples deliberately keep AppDelegate-only behavior by
default; CI selects their scene manifests with `CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene`. The
`CIO_SCENE_CONTRACT_SELF_TEST` block is fixture-only, and the sample imports its Live Activities
attributes module because that extension is included in the sample app.

Android needs no equivalent step.

# Contributing

Thanks for taking an interest in our project! We welcome your contributions. 

The checked-in public API baseline is generated with the exact Flutter version
in `scripts/api-extraction-flutter-version.txt` and `dart_apitool` 0.22.1. The
pin avoids the unsupported Dart 3.13 analyzer AST in newer Flutter releases.
Run `./scripts/extract_api.sh` with that Flutter version when an intentional
public API change requires a new baseline.

We value an open, welcoming, diverse, inclusive, and healthy community for this project. We expect all  contributors to follow our [code of conduct](CODE_OF_CONDUCT.md).

# License

[MIT](LICENSE)
