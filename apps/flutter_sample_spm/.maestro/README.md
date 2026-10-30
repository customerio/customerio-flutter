# Flutter iOS scene push E2E

`run_scene_push.sh` builds the checked-in single-scene host, or accepts the
prebuilt scene app from CI, installs it on a
booted iPhone simulator, grants notification permission through Maestro, and
opens a Customer.io-shaped HTTPS notification. The final assertion proves that
the notification tap passed through the native SDK callback and Flutter's
router to the Settings destination. Without the callback bridge in #399, the
same URL opens outside the app and the assertion fails.

The test-only launch argument makes the sample call the system authorization
API, and Maestro accepts the real system prompt. A missing grant is then caught
before the notification-routing assertion can pass.

The runner temporarily builds with the checked-in placeholder workspace
configuration, then restores any developer-local configuration before exit.
When it builds locally, it runs `flutter clean` to prevent stale Flutter/Xcode
module caches from invalidating the result.

The checked-in payload uses `simctl push` so the destination is deterministic
and does not require changing a shared Customer.io campaign. It validates the
client routing path, not backend `sent`, `delivered`, or `opened` metrics. Those
metrics remain a separate remote E2E lane using a real workspace and APNs.

Run with Flutter 3.44.8, Maestro 2.8.0, and a booted simulator:

```bash
apps/flutter_sample_spm/.maestro/run_scene_push.sh
```

`run_remote_push.sh` covers that separate backend boundary through the sample's
existing FCM integration. Put a read-only App API key and the `Flutter Testbed`
Pipelines source API key in `.maestro/.env` as shown by
`.maestro/.env.example`. Use Flutter 3.44.8, Maestro 2.8.0, and an installed
iPhone 17 Pro simulator runtime, then run:

```bash
apps/flutter_sample_spm/.maestro/run_remote_push.sh
```

The remote flow identifies a fresh customer, registers an iOS FCM device,
triggers the existing `send_push` automation (campaign 18), requires a matching
backend `delivered` metric, and captures Notification Center diagnostics. It
then attempts the real system-notification activation and requires the same
message's `opened` metric.
Terminated scene routing is covered separately by `run_scene_push.sh`.

The activation gate creates a disposable iPhone 17 Pro simulator so stale
notifications cannot alter SpringBoard grouping. It locates the Flutter
notification through accessibility, reveals its system `Open` action, and
activates that action without screen coordinates. The sample must return to its
foreground screen and Customer.io must record `opened` for the exact delivered
message before the runner accepts that interaction.

In GitHub Actions, apply the `run-remote-push-e2e` label to a trusted,
same-repository pull request to run this release check once for its current
head. It does not run for ordinary pull-request updates or on a schedule.
