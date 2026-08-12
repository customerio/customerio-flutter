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
# xcodebuild command line. Flutter's config-only generation writes shared files
# below each sample, so lifecycle builds for the same sample are serialized even
# when they use different DerivedData directories.
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
if [ -n "${CIO_LIFECYCLE_LOCK_TEST_HOLD_SECONDS:-}" ]; then
  APP_DIR="${CIO_LIFECYCLE_BUILD_LOCK_TEST_APP_DIR:?test app directory is required}"
fi
FLUTTER="${FLUTTER:-flutter}"
DERIVED_DATA="${DERIVED_DATA:-$APP_DIR/build/lifecycle-fixture-derived-data/$MODE}"

# Fail loudly rather than silently producing evidence from the wrong toolchain.
PINNED_VERSION="$(tr -d '[:space:]' < "$APP_DIR/.flutter-version")"
ACTUAL_VERSION="$("$FLUTTER" --version --machine | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')"
if [ "$PINNED_VERSION" != "$ACTUAL_VERSION" ]; then
  echo "Flutter version mismatch: .flutter-version pins $PINNED_VERSION, \$FLUTTER reports ${ACTUAL_VERSION:-unknown}" >&2
  exit 1
fi

# Own every shared mutation from config-only generation through product
# verification. A directory lock is used because macOS does not ship flock.
# SIGKILL can leave this directory behind; the error below gives the exact,
# bounded recovery path instead of guessing that an existing lock is stale.
if [ -L "$APP_DIR" ] || [ ! -d "$APP_DIR" ]; then
  echo "lifecycle fixture sample directory is unsafe: $APP_DIR" >&2
  exit 1
fi
RESOLVED_APP_DIR="$(cd "$APP_DIR" && pwd -P)"
BUILD_ROOT="$APP_DIR/build"
if [ -L "$BUILD_ROOT" ]; then
  echo "lifecycle fixture build directory is a symlink: $BUILD_ROOT" >&2
  exit 1
fi
if [ ! -e "$BUILD_ROOT" ]; then
  mkdir "$BUILD_ROOT"
fi
if [ ! -d "$BUILD_ROOT" ] || [ -L "$BUILD_ROOT" ]; then
  echo "lifecycle fixture build directory is unsafe: $BUILD_ROOT" >&2
  exit 1
fi
RESOLVED_BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
case "$RESOLVED_BUILD_ROOT" in
  "$RESOLVED_APP_DIR"/*) ;;
  *)
    echo "lifecycle fixture build directory escapes the sample: $RESOLVED_BUILD_ROOT" >&2
    exit 1
    ;;
esac
LOCK_PARENT="$BUILD_ROOT/lifecycle-fixture-locks"
if [ -L "$LOCK_PARENT" ]; then
  echo "lifecycle fixture lock parent is a symlink: $LOCK_PARENT" >&2
  exit 1
fi
if [ ! -e "$LOCK_PARENT" ]; then
  mkdir "$LOCK_PARENT"
fi
if [ ! -d "$LOCK_PARENT" ] || [ -L "$LOCK_PARENT" ]; then
  echo "lifecycle fixture lock parent is unsafe: $LOCK_PARENT" >&2
  exit 1
fi
RESOLVED_LOCK_PARENT="$(cd "$LOCK_PARENT" && pwd -P)"
case "$RESOLVED_LOCK_PARENT" in
  "$RESOLVED_APP_DIR"/*) ;;
  *)
    echo "lifecycle fixture lock parent escapes the sample: $RESOLVED_LOCK_PARENT" >&2
    exit 1
    ;;
esac
LOCK_DIR="$LOCK_PARENT/build.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  owner="unknown"
  if [ -f "$LOCK_DIR/owner" ] && [ ! -L "$LOCK_DIR/owner" ]; then
    owner="$(sed -n '1p' "$LOCK_DIR/owner")"
  fi
  echo "another $SAMPLE lifecycle build owns $LOCK_DIR (pid $owner)" >&2
  echo "if that pid no longer exists, remove only $LOCK_DIR and retry" >&2
  exit 1
fi
LOCK_OWNED=1
release_build_lock() {
  if [ "${LOCK_OWNED:-0}" != 1 ]; then
    return
  fi
  rm -f "$LOCK_DIR/owner" "$LOCK_DIR/configuration"
  rmdir "$LOCK_DIR"
  LOCK_OWNED=0
}
trap release_build_lock EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "${CIO_LIFECYCLE_LOCK_TEST_FAIL_METADATA_WRITE:-0}" = 1 ]; then
  echo "forced lifecycle fixture lock metadata failure" >&2
  exit 1
fi
printf '%s\n' "$$" > "$LOCK_DIR/owner"
printf '%s %s\n' "$SAMPLE" "$MODE" > "$LOCK_DIR/configuration"

if [ -n "${CIO_LIFECYCLE_LOCK_TEST_HOLD_SECONDS:-}" ]; then
  case "$CIO_LIFECYCLE_LOCK_TEST_HOLD_SECONDS" in
    *[!0-9]* | "") echo "test lock hold must be whole seconds" >&2; exit 2 ;;
  esac
  sleep "$CIO_LIFECYCLE_LOCK_TEST_HOLD_SECONDS"
  exit 0
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
# fixture-only probe to the disposable dependency source.
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
XCODEBUILD_COMMAND=(xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  CIO_LIFECYCLE_INFOPLIST_SUFFIX="$INFOPLIST_SUFFIX" \
  CODE_SIGNING_ALLOWED=NO \
  build)

if [ "$SAMPLE" = "spm" ]; then
  "$REPO_ROOT/apps/scripts/instrument_lifecycle_fixture_dependency.sh" \
    "$SAMPLE" \
    "$GENERATED_DEPENDENCY_ROOT"
  "${XCODEBUILD_COMMAND[@]}"
else
  mkdir -p "$DERIVED_DATA"
  if [ ! -d "$DERIVED_DATA" ] || [ -L "$DERIVED_DATA" ]; then
    echo "CocoaPods DerivedData must be a regular directory: $DERIVED_DATA" >&2
    exit 1
  fi
  export CIO_LIFECYCLE_INSTRUMENTATION_RECEIPT="$DERIVED_DATA/cio-lifecycle-dependency-instrumentation.json"
  "$REPO_ROOT/apps/scripts/instrument_lifecycle_fixture_dependency.sh" \
    "$SAMPLE" \
    "$GENERATED_DEPENDENCY_ROOT" \
    -- \
    "${XCODEBUILD_COMMAND[@]}"
fi

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
