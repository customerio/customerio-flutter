# MBL-2232 Flutter lifecycle producer

Scope: the two sample apps and their fixture-only lifecycle tooling. Published
Flutter and native SDK paths are unchanged. Production adoption remains
MBL-2277.

## Contract and toolchain

The complete 18-file canonical bundle is vendored byte-identically from
`customerio-ios` reviewed content commit
`ce73b1a4ef2b16e178a31ebbda1620034570c0af` under `docs/dev-notes/`. The v2
lock pins that immutable content commit while allowing the native owner to add
its descendant relock commit without a self-reference. The owning lock and
verifier are:

- `docs/dev-notes/ios27-lifecycle-contract-v1.lock.json`
- `scripts/ios27_lifecycle_contract.py`

Verify the bundle with:

```bash
python3 scripts/ios27_lifecycle_contract.py verify --root .
```

Both sample apps pin Flutter 3.44.8 and Dart 3.12-compatible constraints. The
published package keeps its existing Dart and Flutter minimums.

## Real production seats

`AppDelegate` uses one registry-key-guarded registration helper from both the
application did-finish seat and Flutter 3.44.8's
`FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine(_:)`. The
launch seat covers UI-less background wakes through FlutterAppDelegate's
headless launch engine. The callback seat covers callback-created or additional
engines. The helper claims the permission-channel key, invokes
`GeneratedPluginRegistrant`, registers the permission channel on the same
registry, and emits `flutter.plugin-registered` only when registration occurs.
The implicit callback independently emits `flutter.implicit-engine-created`.

The outer Customer.io FCM app delegate owns the actual raw application
did-finish entry, but Customer.io iOS 4.7.2 declares it `public` rather than
`open`. The fixture therefore applies an exact-hash patch only to the generated
SwiftPM/CocoaPods dependency source before compilation. The patch posts one
private Foundation marker at the existing entry before `super`, carrying only
safe launch facts and the harness process-instance ID. The app observer requires
both NotificationCenter object identity and that exact current process-instance
ID. No published SDK source is changed.

The underlying sample AppDelegate records only
`flutter.application.did-finish-launching-forwarded`. It retains its existing
super behavior. There is no dual labeling, no completion interposition, and no
new will-finish or did-become-active application selector. A passive UIKit
did-become-active notification closes the Swift stream.

The scene configuration uses `LifecycleTraceSceneDelegate`, a fixture subclass
of `FlutterSceneDelegate` that observes only its inherited will-connect seat. It
records raw and Flutter-forward entry before `super.scene(...)`, with identical
facts from the real scene, connected-scene set, and connection options.

The Dart producer attaches at the actual Dart main entry. It uses Flutter build
defines because iOS does not expose the native process environment through
`Platform.environment`. It records through a bounded FIFO async sink, marks Dart
records `main_thread: false`, performs no file I/O in the lifecycle observer,
and writes its receipt only after drain. Sink and receipt failures do not affect
sample behavior and make evidence fail closed.

## Reproducible configurations and capture

`Info.plist` is the legacy control. `Info-Scene.plist` is a separate checked-in
UIScene configuration. `apps/scripts/lifecycle_fixture_build.sh` selects one via
a build setting without mutating either plist and generates dependencies. The
SwiftPM build uses an isolated DerivedData source tree and leaves its exact-hash
fixture patch there. The CocoaPods build wrapper backs up the exact original
generated source, applies the patch only for the owned build command, verifies
that the patched bytes survived compilation, restores and re-verifies the
original on success, failure, or catchable interruption, and publishes a
success-only instrumentation receipt for capture provenance.

Config-only generation writes shared `Generated.xcconfig`, registrant, and
dependency files even when builds use separate DerivedData. The build wrapper
therefore holds an exclusive per-sample directory lock from before generation
through product verification for both SwiftPM and CocoaPods. Concurrent builds
fail closed. SIGKILL can leave the lock behind. For SwiftPM, after verifying the
recorded owner PID no longer exists, remove only
`apps/flutter_sample_spm/build/lifecycle-fixture-locks/build.lock` and retry.
For CocoaPods, first require exactly one regular, non-symlink
`ios/Pods/.CioAppDelegateFCM.original.*` backup. It is deliberately outside the
hashed `CustomerIOMessagingPushFCM` dependency root but on the same filesystem
for atomic restoration. Stop rather than guessing if there are zero or multiple
backups. Require the current source hash to be the exact patched
`b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176`
and the backup hash to be the exact original
`f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8`,
atomically move that backup over the generated source, and reverify the original
hash. Only then remove
`apps/flutter_sample_cocoapods/build/lifecycle-fixture-locks/build.lock` and
retry. Safely regenerating the entire Pods tree is the alternative recovery;
never perform a lock-only CocoaPods recovery while generated source is patched.

The capture runner creates one identity before compilation, carries matching
IDs into Dart build defines and Swift launch environment, installs the app,
waits for both streams and receipts, binds them to the same launched PID/process
instance, records repository/dependency/toolchain provenance, and invokes the
vendored validator.

L2 capture requires explicit `manual-app-icon` mode. The runner verifies that
the app is not running, installs the matching launch environment in the booted
simulator's launchd domain, and prints `READY`. When ready to perform the
stimulus, the operator presses Enter and then immediately taps the app's Home
Screen icon after `TAP NOW` appears. The manifest's `initiated_at` is the
operator-confirmation timestamp, not an OS-generated proof of the tap, so the
remaining human timing uncertainty must be retained when evaluating evidence.
This mode never calls `simctl launch`; it fails closed without confirmation or
if no external launch produces the matching streams. It attempts and verifies
removal of every temporary simulator environment value, including on timeout or
interruption, and rejects the run if that cleanup is incomplete:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PUB_CACHE="$(mktemp -d)"
validator_venv="$(mktemp -d)"
python3 -m venv "$validator_venv"
"$validator_venv/bin/pip" install 'jsonschema[format]>=4.18,<5'

python3 apps/lifecycle_fixture/run_flutter_lifecycle_capture.py \
  --source-root "$PWD" \
  --output-dir "$(mktemp -d)/scene-capture" \
  --simulator-id BOOTED_SIMULATOR_UDID \
  --mode scene \
  --sample spm \
  --stimulus-mode manual-app-icon \
  --flutter /path/to/flutter-3.44.8/bin/flutter \
  --validator-python "$validator_venv/bin/python"
```

For build and runner diagnostics only, use `--stimulus-mode
simctl-diagnostic`. That mode invokes `simctl launch`, labels the stimulus
`simulator-control`, records evidence level `diagnostic`, and can never produce
an app-icon or L2 claim. Its output is not acceptance evidence, even if its
individual files are schema-valid.

The runner converts catchable `SIGHUP` and `SIGTERM` into capture failures and
keeps both signals suppressed until launch-environment cleanup is verified.
`SIGINT` retains Python's normal `KeyboardInterrupt` path through the same
`finally` cleanup. `SIGKILL` cannot be caught; after such a termination, verify
and clear only the documented `CIO_LIFECYCLE_*` simulator launchd values before
another run.

The runner fails closed for missing files/receipts, compiled-ID or stream
mismatches, PID disagreement, drops/overflow, unsafe paths, wrong toolchains,
and canonical validator rejection.

## Evidence boundary

Early legacy and scene runs proved the native callback order, but also showed
that Dart main enters after native active and therefore receives no real initial
`didChangeAppLifecycleState(resumed)` callback. Those negative observations are
preserved in
`apps/lifecycle_fixture/evidence/incomplete-icon-cold-launch-observations.json`.
They are explicitly not manifests and make no L2 acceptance claim.

Final L2 can be claimed only for a complete `manual-app-icon` runner output
whose Swift and Dart streams, zero-drop receipts, provenance manifest, and
aggregate validate under the frozen canonical bundle. Automated `simctl
launch` captures, including every earlier output that mislabeled this stimulus
as `app-icon`, are invalidated and must not be cited as L2. No accepted
post-fix manual L2 capture exists while the Mac is locked. Xcode 27,
iOS 27, physical devices, APN/FCM delivery, and L3 remain out of scope.
