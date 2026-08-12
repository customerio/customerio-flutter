#!/usr/bin/env bash
#
# Deterministic iOS Simulator build of one MBL-2232 lifecycle configuration.
#
#   ./apps/scripts/lifecycle_fixture_build.sh <legacy|scene> <cocoapods|spm> [derived-data-dir]
#
# The two configurations differ only by which Info.plist the Runner target uses:
#
#   legacy -> Runner/Info.plist        (no scene manifest, UIApplicationDelegate lifecycle)
#   scene  -> Runner/Info-Scene.plist  (UIApplicationSceneManifest -> FlutterSceneDelegate)
#
# The switch is the `CIO_LIFECYCLE_INFOPLIST_SUFFIX` build setting, passed on the
# xcodebuild command line. Nothing in the working tree is edited, so both
# configurations are reproducible from a clean checkout and can be built in any
# order (or concurrently, with separate derived-data directories).
#
# Required/honoured environment:
#   DEVELOPER_DIR  Xcode to build with. Set this before `flutter pub get` too.
#   FLUTTER        flutter binary to use. Defaults to `flutter` on PATH; must
#                  match the sample's .flutter-version.
#   PUB_CACHE      Set to an isolated directory to keep resolution deterministic.

set -euo pipefail

MODE="${1:-}"
SAMPLE="${2:-}"
DERIVED_DATA="${3:-}"

case "$MODE" in
  legacy) INFOPLIST_SUFFIX="" ;;
  scene) INFOPLIST_SUFFIX="-Scene" ;;
  *)
    echo "usage: $0 <legacy|scene> <cocoapods|spm> [derived-data-dir]" >&2
    exit 2
    ;;
esac

case "$SAMPLE" in
  cocoapods | spm) ;;
  *)
    echo "usage: $0 <legacy|scene> <cocoapods|spm> [derived-data-dir]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/flutter_sample_$SAMPLE"
FLUTTER="${FLUTTER:-flutter}"
DERIVED_DATA="${DERIVED_DATA:-$APP_DIR/build/lifecycle-fixture-derived-data/$MODE}"

# Fail loudly rather than silently producing evidence from the wrong toolchain.
PINNED_VERSION="$(tr -d '[:space:]' < "$APP_DIR/.flutter-version")"
ACTUAL_VERSION="$("$FLUTTER" --version --machine | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"
if [ "$PINNED_VERSION" != "$ACTUAL_VERSION" ]; then
  echo "Flutter version mismatch: .flutter-version pins $PINNED_VERSION, \$FLUTTER reports ${ACTUAL_VERSION:-unknown}" >&2
  exit 1
fi

echo "==> $SAMPLE / $MODE"
echo "    flutter      $ACTUAL_VERSION ($FLUTTER)"
echo "    Info.plist   Runner/Info${INFOPLIST_SUFFIX}.plist"
echo "    derivedData  $DERIVED_DATA"

cd "$APP_DIR"

# Generates Generated.xcconfig, the plugin registrant, and (for the CocoaPods
# sample) runs `pod install`. It does not compile, so it cannot bake the mode in.
FLUTTER_CONFIG_ARGS=(build ios --simulator --debug --config-only)
DART_DEFINE_KEYS=(
  CIO_LIFECYCLE_DART_OUTPUT_BASENAME
  CIO_LIFECYCLE_MANIFEST_ID
  CIO_LIFECYCLE_RUN_ID
  CIO_LIFECYCLE_DART_STREAM_ID
  CIO_LIFECYCLE_PROCESS_INSTANCE_ID
  CIO_LIFECYCLE_SCENARIO
  CIO_LIFECYCLE_EVIDENCE_LEVEL
  CIO_LIFECYCLE_INTEGRATION
  CIO_LIFECYCLE_PROVIDER
)
if [ -n "${CIO_LIFECYCLE_MANIFEST_ID:-}" ]; then
  for key in "${DART_DEFINE_KEYS[@]}"; do
    value="${!key:-}"
    if [ -z "$value" ]; then
      echo "missing Dart harness build value: $key" >&2
      exit 1
    fi
    FLUTTER_CONFIG_ARGS+=("--dart-define=$key=$value")
  done
fi
"$FLUTTER" "${FLUTTER_CONFIG_ARGS[@]}"

# The pinned FCM wrapper owns the actual outer did-finish entry but declares
# that override public rather than open. Resolve first, then apply the exact
# fixture-only probe to the disposable dependency source. The patch script
# accepts only the audited original or already-patched hash.
if [ "$SAMPLE" = "spm" ]; then
  xcodebuild \
    -resolvePackageDependencies \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -derivedDataPath "$DERIVED_DATA" \
    >/dev/null
  GENERATED_DEPENDENCY_ROOT="$DERIVED_DATA"
else
  GENERATED_DEPENDENCY_ROOT="$APP_DIR"
fi
"$REPO_ROOT/apps/scripts/instrument_lifecycle_fixture_dependency.sh" \
  "$SAMPLE" \
  "$GENERATED_DEPENDENCY_ROOT"

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  CIO_LIFECYCLE_INFOPLIST_SUFFIX="$INFOPLIST_SUFFIX" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PLIST="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Runner.app/Info.plist"
if [ ! -f "$APP_PLIST" ]; then
  echo "built app has no Info.plist at $APP_PLIST" >&2
  exit 1
fi

# Prove the built product actually carries the configuration that was asked for,
# instead of trusting that the build setting reached the Runner target.
if plutil -extract UIApplicationSceneManifest xml1 -o - "$APP_PLIST" >/dev/null 2>&1; then
  BUILT_MODE="scene"
else
  BUILT_MODE="legacy"
fi

if [ "$BUILT_MODE" != "$MODE" ]; then
  echo "built product is '$BUILT_MODE' but '$MODE' was requested" >&2
  exit 1
fi

echo "==> OK $SAMPLE / $MODE (built product verified as $BUILT_MODE)"
