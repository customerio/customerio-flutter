# Flutter iOS scene push E2E

`run_scene_push.sh` builds the checked-in single-scene host, or accepts the
prebuilt scene app from CI, installs it on a
booted iPhone simulator, grants notification permission through Maestro, and
opens a Customer.io-shaped HTTPS notification. The final assertion proves that
the notification tap passed through the native SDK callback and Flutter's
router to the Settings destination. Without the callback bridge in #399, the
same URL opens outside the app and the assertion fails.

The runner temporarily builds with the checked-in placeholder workspace
configuration, then restores any developer-local configuration before exit.
When it builds locally, it runs `flutter clean` to prevent stale Flutter/Xcode
module caches from invalidating the result.

The checked-in payload uses `simctl push` so the destination is deterministic
and does not require changing a shared Customer.io campaign. It validates the
client routing path, not backend `sent`, `delivered`, or `opened` metrics.

Run with Flutter 3.44.8, Maestro 2.8.0, and a booted simulator:

```bash
apps/flutter_sample_spm/.maestro/run_scene_push.sh
```

`run_remote_push.sh` covers that separate backend boundary through the sample's
existing FCM integration. Put a read-only App API key and the `Flutter Testbed`
Pipelines source API key in `.maestro/.env` as shown by
`.maestro/.env.example`. Use Flutter 3.44.8 and Maestro 2.8.0, then run:

```bash
apps/flutter_sample_spm/.maestro/run_remote_push.sh
```

The remote flow identifies a fresh customer, registers an iOS FCM device,
triggers the existing `send_push` automation (campaign 18), requires a matching
backend `delivered` metric, and verifies that the notification is visible in
Notification Center. It then attempts the real system-notification activation
and requires the app to reopen plus the same message's `opened` metric.
Terminated scene routing is covered separately by `run_scene_push.sh`.

The activation gate is intentionally strict. On the supported simulator,
Notification Center requires selecting the notification and then its system
Open action by coordinate. The runner accepts that interaction only when the
app reopens and Customer.io records `opened` for the exact delivered message.
Pull requests do not receive the required workspace credentials, so this stays
a local or trusted pre-release check rather than a required PR lane.
