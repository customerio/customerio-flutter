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
supported by Xcode, follow the [deployment-target normalization guide](doc/cocoapods-deployment-target-normalization.md).

# Live Activities

Enable the activity types you use via `liveNotificationsConfig` in your `CustomerIOConfig`. On iOS, Live Activities are opt-in: add the `liveactivities` pod subspec (CocoaPods) or set `customerio_live_activities_enabled=true` in `android/gradle.properties` (Swift Package Manager), plus a Widget Extension that renders the SDK's built-in templates.

iOS also requires `NSSupportsLiveActivities` in `ios/Runner/Info.plist`. Without it the system refuses to start any activity, so nothing appears even when everything else is configured:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

For an activity of your own, set `customType` to your reverse-DNS identifier and start it with `LiveActivityPayload.custom(data: {...})`. You supply the view: `CIOCustomAttributes` in your iOS Widget Extension, and the `createLiveNotification` callback on Android.

AppDelegate-only apps keep the existing `application(_:open:options:)` integration: call
`CustomerIOLiveActivities.handleWidgetUrl` before forwarding its returned URL to the host router.
This remains the supported legacy behavior and avoids a second automatic observer reporting the
same tap.

For UIScene apps using Flutter's standard deep-link handling, the plugin automatically attributes
Live Activity taps. If a tap carries a redirect, it waits for Flutter UI in that scene and sends
the URL through Flutter's route-information channel. If Flutter declines the route, the plugin logs
the result and does not ask iOS to reopen the URL; reopening an app's own universal link can send it
to the website instead. Do not add another Customer.io URL handler to the host `SceneDelegate`.
When upgrading an existing UIScene app that added this handler manually, remove that call before
upgrading to avoid reporting the same tap twice.

If a UIScene app sets `FlutterDeepLinkingEnabled` to `false` and owns routing through another
plugin, keep the host scene lifecycle handler. Call `CustomerIOLiveActivities.handleWidgetUrl`
there before forwarding its returned URL to that router. Customer.io does not register an
automatic URL owner in this configuration.

Apps with a `UIApplicationSceneManifest` receive opened URLs through their scene lifecycle instead
of the AppDelegate callback. The host scene delegate must extend Flutter's `FlutterSceneDelegate`,
or forward the equivalent lifecycle callbacks through Flutter's scene lifecycle provider. The
Customer.io plugin then registers its scene routing owner; do not add another Customer.io URL
handler to the host `SceneDelegate`. The samples deliberately keep AppDelegate-only behavior by
default, while CI selects their scene manifests with
`CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene`. Flutter exposes one consume-or-forward decision for all
cold connection options, so an occurrence that also contains a user activity, notification
response, or shortcut is not consumed by Customer.io. Customer.io still records the opened metric
when the occurrence contains exactly one tracking URL, then returns the complete original
occurrence to Flutter; it does not route the redirect from that mixed occurrence. Depending on
which other input Flutter handles first, its router may also receive the original
`cio-live-activity` URL; treat that internal URL as unhandled.
Warm URL callbacks are offered to every engine associated with the scene, while Flutter gives cold
connection options to the first engine that claims them. CI proves scene launch and callback
delivery, but real URL delivery into the Flutter engine remains part of device-level validation.

Android needs no equivalent step.

# iOS application lifecycle

Existing AppDelegate-only applications remain supported and require no new Customer.io
configuration when built with toolchains that still permit that lifecycle. Apps built with Xcode
27 must adopt UIScene to launch. The plugin uses scene routing when the app declares Apple's
standard `UIApplicationSceneManifest`; no Customer.io-specific lifecycle key is required.

Keep `CioAppDelegateWrapper` as the application delegate. It continues to own SDK initialization,
APNs token registration, and the global notification-center delegate. Flutter's scene delegate owns
UI activation callbacks. In UIScene hosts, the plugin passes Customer.io Live Activity URLs to the
released native URL handler and leaves ordinary links and user activities to Flutter.
AppDelegate-only hosts keep the existing manual URL handler described above.
When UIScene and Flutter deep linking are enabled, the plugin also becomes the native SDK's
deep-link callback during plugin registration. The native callback is synchronous but Flutter's
routing result is asynchronous, so the plugin claims the handoff, offers the destination to Flutter,
and uses `UIApplication.open` only if Flutter declines it or no foreground engine becomes available.
This replaces the native SDK's AppDelegate continuation fallback only in that UIScene configuration;
set `FlutterDeepLinkingEnabled` to `false` when the host owns a different scene router.
Applications that declare UIScene must use Flutter 3.44.8 or newer and use
`FlutterSceneDelegate`, or forward its lifecycle callbacks through Flutter's scene lifecycle
provider. Customer.io cannot receive or diagnose callbacks that a custom scene delegate does not
forward. This release's compatibility scope is one simultaneous window scene, matching the native
and Flutter samples' `UIApplicationSupportsMultipleScenes=false` configuration. Multiple
simultaneous window scenes are not supported. Hosts that enable them retain ownership of Flutter's
scene-to-engine registration and any window-specific routing. Older Flutter registrars log an error
and leave scene routing unclaimed.

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
