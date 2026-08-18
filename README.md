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

The plugin automatically attributes Live Activity taps. If a tap carries a redirect, the plugin
first passes it through the existing Flutter and host URL handlers, then asks iOS to open it when
those handlers decline it. No AppDelegate URL override is required. Remove the earlier manual
Customer.io Live Activity URL override after upgrading so one tap has one routing owner.

Apps with a `UIApplicationSceneManifest` receive opened URLs through their scene lifecycle instead
of the AppDelegate callback above. The Customer.io plugin registers that scene routing owner; do
not add another Customer.io URL handler to your host `SceneDelegate`. The samples deliberately keep
AppDelegate-only behavior by default, while CI selects their scene manifests with
`CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene`. Flutter exposes one consume-or-forward decision for all
cold connection options, so a mixed user-activity and URL occurrence is left wholly to Flutter
rather than partially consumed. CI proves scene launch and callback delivery, but real URL delivery
into the Flutter engine remains part of device-level validation.

Android needs no equivalent step.

# iOS application lifecycle

Existing AppDelegate-only applications remain the default and require no new configuration. A
UIScene application must explicitly declare its lifecycle owner in `ios/Runner/Info.plist`:

```xml
<key>CustomerIOAppLifecycleHostTopology</key>
<string>ui-scene</string>
```

Keep `CioAppDelegateWrapper` as the application delegate. It continues to own SDK initialization,
APNs token registration, and the global notification-center delegate. Flutter's scene delegate owns
UI activation callbacks. For existing AppDelegate-only hosts, the plugin calls the Live Activity URL
primitive directly. For UIScene hosts, it validates callbacks with the native scene coordinator.
Both paths leave ordinary links and user activities to Flutter. Applications that declare UIScene
must use Flutter 3.44.8 or newer; older Flutter registrars log an error and leave scene routing
unclaimed.

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
