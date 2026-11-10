# Silent push

A silent push shows nothing to the person. It wakes your app and hands it the data set on the
message, so the app can refresh content or sync state. Customer.io sends it to every iOS and Android
device of the person, and your app decides what to do with it.

A Flutter app receives it in one of two ways, depending on what handles push in the app:

- [Customer.io handles push](#customerio-handles-push): register a Dart handler with
  `CustomerIO.pushMessaging.setBackgroundPushHandler`.
- [firebase_messaging handles push](#firebase_messaging-handles-push): your existing
  `firebase_messaging` handlers receive it.

Use one of them. An app that does both runs its Dart code twice for every silent push.

## What a silent push contains

Your data as text keys and text values, plus two keys Customer.io adds:

| Key | Value |
| --- | --- |
| `CIO-Background-Delivery-ID` | Identifies the delivery |
| `CIO-Background-Delivery-Token` | The device token it was sent to |

The SDK records the Delivered metric when the push arrives, before your code runs. It never records
Opened. Silent push needs Customer.io Android SDK 5.1.0 and iOS SDK 5.2.0, which this plugin
release uses.

Delivery is best effort:

- The same push can arrive more than once. Key your work on the delivery ID.
- A push can arrive late, for example while Android holds messages for an idle device.
- After a device has been offline, iOS delivers only the newest push.
- iOS doesn't wake an app the person force-quit, and Android doesn't deliver to an app the person
  force-stopped.

## Customer.io handles push

Use this when Customer.io's `FirebaseMessagingService` receives messages on Android and
`CioAppDelegateWrapper` is your app delegate on iOS.

Write a top-level or static handler annotated with `@pragma('vm:entry-point')`, and register it at
the start of `main`, before other `await`s:

```dart
@pragma('vm:entry-point')
Future<void> onBackgroundPush(CustomerIOBackgroundPush push) async {
  // push.data holds your keys. push.deliveryId identifies the delivery.
  await refreshAccount(push.data['account']);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CustomerIO.pushMessaging.setBackgroundPushHandler(onBackgroundPush);
  // Firebase, CustomerIO.initialize, runApp and the rest.
}
```

The handler gets your data without the two Customer.io keys. The plugin remembers the registration
across launches: on Android a push that starts your app runs the handler without your `main`, and on
iOS it waits for `main` to register the handler again. To stop, call
`setBackgroundPushHandler(null)`.

If you turned automatic push tracking off, record Delivered yourself from an isolate where
`CustomerIO.initialize` has run:

```dart
CustomerIO.instance.trackMetric(
  deliveryID: push.deliveryId,
  deviceToken: push.deliveryToken,
  event: MetricEvent.delivered,
);
```

### Android

Nothing else to set up. The handler runs from a WorkManager job:

- On the main isolate of a running Flutter engine that registered the handler, such as your app's
  UI engine.
- Otherwise on a background isolate the plugin starts, the way `firebase_messaging` runs
  `onBackgroundMessage`. It shares nothing with the rest of the app and has no UI. Plugins work
  there, and `CustomerIO.instance` doesn't, since `CustomerIO.initialize` hasn't run in it.

The job keeps the process running until the handler finishes, and Android stops it after 10
minutes. If the process dies or the app's engine goes away first, WorkManager runs the job again,
so the handler can see the same push twice.

### iOS

1. In Xcode, add **Background Modes > Remote notifications**, or iOS doesn't wake the app.
2. Keep `CioAppDelegateWrapper` as the app delegate. The plugin receives silent pushes from it.
3. Register plugins in `application(_:didFinishLaunchingWithOptions:)` with
   `GeneratedPluginRegistrant.register(with: self)`, as the samples do, so Dart runs when iOS
   launches the app in the background.
4. FCM apps with Firebase's app delegate proxy on (the default) need GoogleUtilities 8.1.5 or later,
   or the push never reaches the SDK.

The handler runs on the main isolate. The push completes when the handler finishes, or after 25
seconds, within the 30 seconds iOS allows.

Once the app has registered a handler, the plugin takes Customer.io silent pushes from
`CioAppDelegateWrapper`, so a `didReceiveRemoteNotification` override in your app delegate doesn't
see them. `firebase_messaging` still gets them through Firebase's app delegate proxy, and doesn't
with the proxy off.

## firebase_messaging handles push

Use this when `firebase_messaging` receives your messages and forwards them to Customer.io. Silent
pushes reach `FirebaseMessaging.onBackgroundMessage` and `onMessage` with no change on your side.
`message.notification` is null and `message.data` holds your keys plus the two Customer.io keys.

```dart
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  if (message.data['CIO-Background-Delivery-ID'] != null) {
    await refreshAccount(message.data['account']);
  }
  await CustomerIO.pushMessaging.onBackgroundMessageReceived(message.toMap());
}
```

Keep forwarding every message to `onBackgroundMessageReceived` or `onMessageReceived`. For a silent
push on Android it records Delivered, shows nothing and resolves to `true`. On iOS it resolves to
`true`, and `CioAppDelegateWrapper` records Delivered. Don't show a notification for a silent push
yourself.

`firebase_messaging` sets the background isolate rules:

- `onBackgroundMessage` takes a top-level or static function annotated with
  `@pragma('vm:entry-point')`, registered before `runApp`.
- On Android it runs in a separate isolate with no shared state and no UI. Call
  `Firebase.initializeApp()` there before using Firebase.
  `CustomerIO.pushMessaging.onBackgroundMessageReceived` works there without `CustomerIO.initialize`.
- On iOS it runs on the main isolate.
- Firebase gives each message only a short window on Android, and iOS allows about 30 seconds. Hand
  longer work to a background job.
