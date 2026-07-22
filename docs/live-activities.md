# Live Activities (iOS) / Live Notifications (Android)

`CustomerIO.liveActivities` shows a live, updating notification driven by a built-in template.
Two templates ship today: **Segments** and **Countdown Timer**.

- **Android** renders built-in templates entirely inside the SDK — **no native code required**.
- **iOS** requires a **Widget Extension** in your app to render (ActivityKit has no data-only
  entry point). The built-in templates' SwiftUI ships in the SDK, so your widget file is ~10 lines
  (below). Live Activities need **iOS 16.2+** (push-to-start needs 17.2+).

## Enable templates at init

```dart
await CustomerIO.instance.initialize(
  config: CustomerIOConfig(
    cdpApiKey: '…',
    liveActivitiesConfig: LiveActivitiesConfig(
      templates: [LiveActivityTemplate.segments, LiveActivityTemplate.countdownTimer],
      // Android-only branding (iOS branding is compiled into the widget):
      branding: LiveActivitiesBranding(
        companyName: 'Acme',
        accentColorHex: '#FF6D00',
        logoUrl: 'https://…/logo.png',
      ),
    ),
  ),
);
```

## Start / update / end

```dart
// Segments
final id = await CustomerIO.liveActivities.start(
  LiveActivityPayload.segments(
    header: 'Order #4021',
    status: 'Preparing your order',
    segmentsTotal: 4,
    segmentsComplete: 1,
  ),
);

// update() replaces the whole content-state — pass the FULL desired state each time.
await CustomerIO.liveActivities.update(
  id,
  LiveActivityPayload.segments(
    header: 'Order #4021',
    status: 'Out for delivery',
    segmentsTotal: 4,
    segmentsComplete: 3,
  ),
);

await CustomerIO.liveActivities.end(id);

// Countdown Timer — endTime is epoch SECONDS
final c = await CustomerIO.liveActivities.start(
  LiveActivityPayload.countdownTimer(
    header: 'Flash Sale',
    title: '50% off ends in',
    endTime: DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  ),
);
```

`start` returns an `activityId` — the only handle you need for `update`/`end`. There is no
lifecycle event callback; delivery/lifecycle metrics are reported to Customer.io automatically.

### Custom types

`startCustom(activityType, data)` starts an app-defined type. **Android** renders it via your
`CustomerIOPushNotificationCallback.createLiveNotification` callback. **On iOS this throws** —
custom types require a native Widget Extension + `ActivityAttributes` and an `adopt()` call.

### Deep-link / opened metric (iOS)

Call `CustomerIO.liveActivities.handleDeepLinkOpen(url)` from your URL-handling entry point to
report an `opened` metric when the app is opened from a tapped Live Activity. No-op on Android.

## iOS setup (one time)

1. Add `NSSupportsLiveActivities = YES` to your app's `Info.plist`.
2. Add a **Widget Extension** target (File ▸ New ▸ Target ▸ Widget Extension). In its target,
   depend on `CustomerIO/LiveActivitiesTemplates` and `CustomerIO/LiveActivitiesAttributes`
   (CocoaPods) or the `LiveActivities_Templates` / `LiveActivities_Attributes` SwiftPM products.
3. Replace the generated widget bundle with the built-in templates:
   ```swift
   import WidgetKit
   import CioLiveActivities_Templates   // ships CIOSegmentsLiveActivity, CIOCountdownTimerLiveActivity
   import CioLiveActivities_Attributes

   @main
   struct CIOLiveActivitiesWidgets: WidgetBundle {
       var body: some Widget {
           CIOSegmentsLiveActivity()
           CIOCountdownTimerLiveActivity()
       }
   }
   ```

## Android setup

Nothing beyond the standard `messaging-push-fcm` setup — built-in templates render in-SDK.
