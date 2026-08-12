# MBL-2232 Flutter lifecycle producer

Scope: the two sample apps and their fixture-only lifecycle tooling. Published
Flutter and native SDK paths are unchanged. Production adoption remains
MBL-2277.

## Contract and toolchain

The complete 18-file canonical bundle is vendored byte-identically from
`customerio-ios` canonical content commit
`5b8c02e4c85203d073a85da8abb2212b19867e68` under `docs/dev-notes/`. The
owning lock and verifier are:

- `docs/dev-notes/ios27-lifecycle-contract-v1.lock.json`
- `scripts/ios27_lifecycle_contract.py`

Verify the bundle with:

```bash
python3 scripts/ios27_lifecycle_contract.py verify --root .
```

Both sample apps pin Flutter 3.44.8 and Dart 3.12-compatible constraints. The
published package keeps its existing Dart and Flutter minimums.

## Real production seats

`AppDelegate` implements Flutter 3.44.8's
`FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine(_:)` and uses
`engineBridge.pluginRegistry`. It claims one per-engine guard key, invokes
`GeneratedPluginRegistrant` once, registers the permission channel on the same
registry, then emits the canonical engine/plugin bootstrap observations.

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
a build setting without mutating either plist, generates dependencies, applies
the fail-closed generated-source patch, then builds.

The capture runner creates one identity before compilation, carries matching
IDs into Dart build defines and Swift launch environment, installs and launches
one simulator stimulus, waits for both streams and receipts, binds them to the
same launched PID/process instance, records repository/dependency/toolchain
provenance, and invokes the vendored validator:

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
  --flutter /path/to/flutter-3.44.8/bin/flutter \
  --validator-python "$validator_venv/bin/python"
```

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

Final L2 is claimed only for a complete runner output whose Swift and Dart
streams, zero-drop receipts, provenance manifest, and aggregate validate under
the frozen canonical bundle. Xcode 27, iOS 27, physical devices, APN/FCM
delivery, and L3 remain out of scope.
