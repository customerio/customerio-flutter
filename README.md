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

# Live Activities

Enable the activity types you use via `liveNotificationsConfig` in your `CustomerIOConfig`. On iOS, Live Activities are opt-in: add the `liveactivities` pod subspec (CocoaPods) or set `customerio_live_activities_enabled=true` in `android/gradle.properties` (Swift Package Manager), plus a Widget Extension that renders the SDK's built-in templates.

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

Android needs no equivalent step.

# Contributing

Thanks for taking an interest in our project! We welcome your contributions. 

We value an open, welcoming, diverse, inclusive, and healthy community for this project. We expect all  contributors to follow our [code of conduct](CODE_OF_CONDUCT.md).

# License

[MIT](LICENSE)
