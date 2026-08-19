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

The plugin automatically attributes Live Activity taps. If a tap carries a redirect, it waits for
the owning Flutter engine and sends the URL through Flutter's standard route-information channel.
If Flutter declines the route, the plugin logs the result and does not ask iOS to reopen the URL;
reopening an app's own universal link can send it to the website instead. No AppDelegate URL
override is required when Flutter's standard deep-link handling is enabled.

If your app sets `FlutterDeepLinkingEnabled` to `false` and owns routing through another plugin,
keep your existing host lifecycle handler. Call `CustomerIOLiveActivities.handleWidgetUrl` there
before forwarding the returned URL to that router. Customer.io does not register an automatic URL
owner in this configuration.

When using Flutter's standard deep-link handling, remove the AppDelegate URL override shown in
older Customer.io documentation. If an existing override already unwraps the tracking URL before
calling `super`, it remains safe during migration, but it is no longer required. An override that
forwards the original Customer.io tracking URL after calling `handleWidgetUrl` must be removed to
avoid reporting the same tap twice.

Apps with a `UIApplicationSceneManifest` receive opened URLs through their scene lifecycle instead
of the AppDelegate callback. The host scene delegate must extend Flutter's `FlutterSceneDelegate`,
or forward the equivalent lifecycle callbacks through Flutter's scene lifecycle provider. The
Customer.io plugin then registers its scene routing owner; do not add another Customer.io URL
handler to the host `SceneDelegate`. The samples deliberately keep AppDelegate-only behavior by
default, while CI selects their scene manifests with
`CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene`. Flutter exposes one consume-or-forward decision for all
cold connection options, so an occurrence that also contains a user activity, notification
response, or shortcut is left wholly to Flutter, including its original URL, rather than partially
consumed. Flutter forwards a scene event to every engine associated with that scene; Customer.io
reports the tap once and delivers the resolved route to those engines using the same fan-out. CI
proves scene launch and callback delivery, but real URL delivery into the Flutter engine remains
part of device-level validation.

Android needs no equivalent step.

# iOS application lifecycle

Existing AppDelegate-only applications remain supported and require no new Customer.io
configuration when built with toolchains that still permit that lifecycle. Apps built with Xcode
27 must adopt UIScene to launch. The plugin uses scene routing when the app declares Apple's
standard `UIApplicationSceneManifest`; no Customer.io-specific lifecycle key is required.

Keep `CioAppDelegateWrapper` as the application delegate. It continues to own SDK initialization,
APNs token registration, and the global notification-center delegate. Flutter's scene delegate owns
UI activation callbacks. In either topology, the plugin passes Customer.io Live Activity URLs to
the released native URL handler and leaves ordinary links and user activities to Flutter.
Applications that declare UIScene must use Flutter 3.44.8 or newer and use
`FlutterSceneDelegate`, or forward its lifecycle callbacks through Flutter's scene lifecycle
provider. Customer.io cannot receive or diagnose callbacks that a custom scene delegate does not
forward. If the app enables multiple scenes and its Flutter engine is not the scene's root view
controller during connection, follow Flutter's manual engine-registration requirement. Older
Flutter registrars log an error and leave scene routing unclaimed.

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
