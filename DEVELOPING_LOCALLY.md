# Developing locally — Visual Notification Inbox UI spike

Branch: `spike/visual-inbox-wrappers`

This spike exposes three native Visual Notification Inbox UI components to Dart via PlatformView,
mirroring the existing inline in-app message PlatformView:

| Widget | iOS native | Android native |
| --- | --- | --- |
| `NotificationInboxOverlay` | `NotificationInboxOverlay(onPanelPresentationChange:)` | `NotificationInboxOverlay(modifier)` |
| `NotificationInboxBell` | `NotificationInboxBell(onTap:)` | `NotificationInboxBell(onClick, modifier)` |
| `NotificationInboxView` | `NotificationInboxView()` | `NotificationInboxView(modifier)` |

The headless inbox data API and the global action `InboxEventListener` are already bridged in this
repo; the widgets here render UI only and surface per-view widget callbacks:
- Overlay: `onPanelPresentationChange(bool presented)` — **iOS only** (see note below).
- Bell: `onTap()`.
- View: no per-view callbacks.

> Platform gap: the Android native `NotificationInboxOverlay` public API does **not** expose a
> panel-presentation callback (iOS does). On Android the Dart `onPanelPresentationChange` never
> fires. To close this gap, the native Android `:messaginginbox` module would need to add an
> `onPanelPresentationChange: (Boolean) -> Unit` parameter to its public `NotificationInboxOverlay`.

These instructions assume the sibling native checkouts already present in this workspace. They are
**read-only references** — do not edit them (publishing the Android artifacts to mavenLocal is fine).

---

## Android (validated — builds green)

Native granular UI lives in the local checkout:
`/Users/melmorabea/Documents/code/public-sdks/wt-759-sample` (branch `inbox-sample-listener`),
module `:messaginginbox`, artifact `io.customer.android:messaging-inbox`, package
`io.customer.messaginginbox`.

1. Publish the native modules (incl. `messaging-inbox`) to your local Maven repo at version `local`:

   ```bash
   cd /Users/melmorabea/Documents/code/public-sdks/wt-759-sample
   IS_DEVELOPMENT=true ./gradlew publishToMavenLocal
   ```

   This publishes all CIO modules at version `local`. Jist is pulled from Maven Central
   (`io.customer.android:jist:0.1.0-alpha01`).

2. This spike already wired `customerio-flutter/android/build.gradle`:
   - `cioVersion = "local"`
   - added `implementation "io.customer.android:messaging-inbox:$cioVersion"`
   - added the Jetpack Compose plugin + runtime (Compose BOM `2025.10.00`, `activity-compose`)
     because the native inbox components are `@Composable` and are hosted inside a `ComposeView`.
     The inline in-app view is a plain Android `View`, so the plugin module previously had no
     Compose dependency.

3. `mavenLocal()` is already present in `apps/flutter_sample_spm/android/settings.gradle`'s
   repositories (and the cocoapods example).

4. Build to validate the plugin Kotlin compiles:

   ```bash
   cd /Users/melmorabea/Documents/code/public-sdks/customerio-flutter/apps/flutter_sample_spm
   cp .env.example .env   # the sample app requires a .env asset (placeholders are fine)
   flutter build apk --debug
   ```

   Result: **green** — `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.

To revert to a normal build: set `cioVersion` back to a released version (e.g. `4.17.0`), remove the
`messaging-inbox` line and the Compose additions in `android/build.gradle`.

---

## iOS (code complete; SPM dependency resolution BLOCKED)

Native granular UI lives in the local checkout:
`/Users/melmorabea/Documents/code/public-sdks/wt-inbox-ios-fix` (branch
`inbox-animation-and-data-fix`), SPM product `MessagingInbox` (target `CioMessagingInbox`), iOS 15
floor, links Jist via an SPM git dependency.

The iOS wrapper source (factories + `UIHostingController`-backed platform views + registrations) is
complete and matches the confirmed native API. **However the SPM dependency graph cannot be
resolved locally** for the reason below, so an end-to-end iOS build is not yet green.

### The blocker

`ios/customer_io/Package.swift` depends on `customerio-ios` for `DataPipelines`, `MessagingInApp`,
`MessagingPushFCM`, and now `MessagingInbox`. It **also** depends on `customerio-ios-fcm`, whose own
`Package.swift` declares a transitive dependency on `customerio-ios` **by URL**
(`https://github.com/customerio/customerio-ios.git`).

To get `MessagingInbox` (only present on the inbox branch), this spike repins the `customerio-ios`
dependency to the local inbox checkout. Two attempts:

1. `.package(name: "customerio-ios", path: "…/wt-inbox-ios-fix")` →
   `multiple similar targets 'CioDataPipelines' … appear in package 'customerio-ios' and
   'wt-inbox-ios-fix'`. SwiftPM keys de-duplication off the path **basename**, not the `name:`
   override, so the path package (`wt-inbox-ios-fix`) and the URL package (`customerio-ios`) are
   treated as two distinct packages exposing the same targets → collision.

2. Detached git worktree whose **directory basename is `customerio-ios`** (created from the inbox
   branch), pinned via `.package(name: "customerio-ios", path: "…/scratchpad/customerio-ios")`.
   The collision goes away (graph resolves), but the **URL source wins the shared identity**:
   SwiftPM clones `customerio-ios.git` (which has no `MessagingInbox` product) instead of using the
   local path, so the build fails with `Unable to find module dependency: 'MessagingInbox'`.

The detached worktree was created with:

```bash
cd /Users/melmorabea/Documents/code/public-sdks/wt-inbox-ios-fix
git worktree add --detach "<scratch>/customerio-ios" inbox-animation-and-data-fix
```

### How to finish the iOS path

A path dependency does not override a same-identity **URL** dependency that arrives transitively
(via `customerio-ios-fcm`). The correct fix is one of:

- **SwiftPM dependency mirror** redirecting `https://github.com/customerio/customerio-ios.git` to the
  local inbox checkout:
  ```bash
  cd "<local customerio-ios inbox checkout>"
  swift package config set-mirror \
    --package-url https://github.com/customerio/customerio-ios.git \
    --mirror-url "<local customerio-ios inbox checkout>"
  ```
  This writes a **machine-global** file (`~/.swiftpm/configuration/mirrors.json`). It was **not**
  applied in this spike because it persists outside the repo and outside the session; apply it
  manually if you accept that, then `flutter build ios --debug --no-codesign` in
  `apps/flutter_sample_spm` after clearing `DerivedData/Runner-*` and the workspace
  `Package.resolved`.

- **Or** temporarily point the local `customerio-ios-fcm` checkout's transitive `customerio-ios`
  dependency at the same local inbox path (an edit to a sibling repo — out of scope for this spike).

- **Or** once `MessagingInbox` ships in a released `customerio-ios` tag, just bump the
  `.package(url:exact:)` pin and drop all of the above.

`ios/customer_io.podspec` also gained a `CustomerIO/MessagingInbox` dependency for the cocoapods
example; that pod is not published yet, so the cocoapods example likewise needs a released native
SDK (or a local podspec path override) to build.

---

## Files touched by this spike

- iOS: `ios/customer_io/Sources/customer_io/MessagingInbox/NotificationInboxViewFactory.swift`,
  `…/MessagingInbox/NotificationInboxPlatformViews.swift`, registration in
  `…/MessagingInApp/CustomerIOInAppMessaging.swift`, `ios/customer_io/Package.swift`,
  `ios/customer_io.podspec`.
- Android: `android/src/main/kotlin/io/customer/customer_io/messaginginbox/NotificationInboxViewFactory.kt`,
  `…/messaginginbox/NotificationInboxPlatformView.kt`, registration + imports in
  `…/messaginginapp/CustomerIOInAppMessaging.kt`, `android/build.gradle`.
- Dart: `lib/messaging_in_app/notification_inbox_views.dart`, exported from
  `lib/customer_io_widgets.dart`.
- Example: `apps/flutter_sample_spm/lib/src/screens/inbox_ui.dart`, wired into
  `lib/src/data/screen.dart`, `lib/src/app.dart`, `lib/src/screens/dashboard.dart`.
