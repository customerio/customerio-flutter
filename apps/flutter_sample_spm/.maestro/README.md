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
client routing path, not backend `sent`, `delivered`, or `opened` metrics. Those
metrics remain a separate remote E2E lane using a real workspace and APNs.

Run with Flutter 3.44.8, Maestro 2.8.0, and a booted simulator:

```bash
apps/flutter_sample_spm/.maestro/run_scene_push.sh
```
