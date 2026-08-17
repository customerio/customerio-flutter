#!/usr/bin/env bash

# Applies the fixture-only raw-launch probe to the exact Customer.io iOS 4.7.2
# FCM source resolved by CocoaPods or SwiftPM. The published wrapper and package
# sources remain untouched. Both the input and result are hash-locked so the
# instrumentation fails closed if dependency resolution changes. SwiftPM lives
# in isolated DerivedData and may remain patched. CocoaPods lives in the sample
# worktree, so this script owns the build command and restores the exact original
# bytes on success, command failure, or interruption.

set -euo pipefail

RESOLUTION="${1:-}"
GENERATED_ROOT="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/../lifecycle_fixture/customerio-ios-fcm-4.7.2-raw-launch.patch"
SNAPSHOT_HELPER="$SCRIPT_DIR/../lifecycle_fixture/dependency_content_snapshot.py"
PATCH_SHA256="f213e7a51dc2eb59c9dbb21d33e32d42d967530933597b1abb06fcdbc2010195"
ORIGINAL_SHA256="f7293e78daa312de780d14094451128fa23d023097a2471682ecfdb7c7ef0ff8"
PATCHED_SHA256="b15fe188aa873c30d15c97c09f0757406c16f38da87a99269f8c8bc7bd26b176"

case "$RESOLUTION" in
  spm)
    [ -n "$GENERATED_ROOT" ] || {
      echo "usage: $0 <spm|cocoapods> <generated-root>" >&2
      exit 2
    }
    SOURCE_SUFFIX="SourcePackages/checkouts/customerio-ios/Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
    ;;
  cocoapods)
    [ -n "$GENERATED_ROOT" ] || {
      echo "usage: $0 <spm|cocoapods> <generated-root>" >&2
      exit 2
    }
    SOURCE_SUFFIX="ios/Pods/CustomerIOMessagingPushFCM/Sources/MessagingPushFCM/Integration/CioAppDelegateFCM.swift"
    shift 2
    if [ "${1:-}" != "--" ] || [ "$#" -lt 2 ]; then
      echo "usage: $0 cocoapods <generated-root> -- <build-command> [args...]" >&2
      exit 2
    fi
    shift
    BUILD_COMMAND=("$@")
    ;;
  *)
    echo "usage: $0 <spm|cocoapods> <generated-root>" >&2
    exit 2
    ;;
esac

case "$GENERATED_ROOT" in
  /*) ;;
  *)
    echo "generated dependency root must be absolute: $GENERATED_ROOT" >&2
    exit 1
    ;;
esac

if [ ! -d "$GENERATED_ROOT" ] || [ -L "$GENERATED_ROOT" ]; then
  echo "generated dependency root must be a regular directory: $GENERATED_ROOT" >&2
  exit 1
fi
RESOLVED_ROOT="$(cd "$GENERATED_ROOT" && pwd -P)"
SOURCE_FILE="$RESOLVED_ROOT/$SOURCE_SUFFIX"

if [ ! -f "$PATCH_FILE" ] || [ -L "$PATCH_FILE" ]; then
  echo "fixture patch must be a regular non-symlink file: $PATCH_FILE" >&2
  exit 1
fi
if [ ! -f "$SNAPSHOT_HELPER" ] || [ -L "$SNAPSHOT_HELPER" ]; then
  echo "dependency snapshot helper must be a regular non-symlink file: $SNAPSHOT_HELPER" >&2
  exit 1
fi
patch_sha="$(shasum -a 256 "$PATCH_FILE" | awk '{print $1}')"
if [ "$patch_sha" != "$PATCH_SHA256" ]; then
  echo "unexpected fixture patch hash: $patch_sha" >&2
  exit 1
fi

if [ ! -f "$SOURCE_FILE" ] || [ -L "$SOURCE_FILE" ]; then
  echo "missing pinned Customer.io source: $SOURCE_FILE" >&2
  exit 1
fi
resolved_source="$(cd "$(dirname "$SOURCE_FILE")" && pwd -P)/$(basename "$SOURCE_FILE")"
if [ "$resolved_source" != "$SOURCE_FILE" ]; then
  echo "resolved Customer.io source escapes the exact generated path: $resolved_source" >&2
  exit 1
fi

actual="$(shasum -a 256 "$SOURCE_FILE" | awk '{print $1}')"
if [ "$RESOLUTION" = "cocoapods" ] && [ "$actual" = "$PATCHED_SHA256" ]; then
  echo "refusing prepatched CocoaPods Customer.io source" >&2
  exit 1
fi
case "$actual" in
  "$ORIGINAL_SHA256") ;;
  "$PATCHED_SHA256") [ "$RESOLUTION" = "spm" ] && exit 0 ;;
  *)
    echo "unexpected Customer.io source hash: $actual" >&2
    exit 1
    ;;
esac

BACKUP_FILE=""
BACKUP_VERIFIED=0
restore_cocoapods_source() {
  trap '' HUP INT TERM
  if [ -z "$BACKUP_FILE" ]; then
    return
  fi
  if [ ! -f "$BACKUP_FILE" ] || [ -L "$BACKUP_FILE" ]; then
    echo "missing CocoaPods source backup during restore" >&2
    return 1
  fi
  if [ "$BACKUP_VERIFIED" != 1 ]; then
    /bin/rm -f "$BACKUP_FILE"
    BACKUP_FILE=""
    return
  fi
  /bin/mv -f "$BACKUP_FILE" "$SOURCE_FILE"
  BACKUP_FILE=""
  BACKUP_VERIFIED=0
  restored="$(shasum -a 256 "$SOURCE_FILE" | awk '{print $1}')"
  if [ "$restored" != "$ORIGINAL_SHA256" ]; then
    echo "restored CocoaPods source hash mismatch: $restored" >&2
    return 1
  fi
}

restore_cocoapods_source_on_exit() {
  exit_status=$?
  trap - EXIT
  if ! restore_cocoapods_source; then
    exit 1
  fi
  exit "$exit_status"
}

if [ "$RESOLUTION" = "cocoapods" ]; then
  trap restore_cocoapods_source_on_exit EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  backup_parent="$RESOLVED_ROOT/ios/Pods"
  if [ ! -d "$backup_parent" ] || [ -L "$backup_parent" ]; then
    echo "CocoaPods source backup parent is unsafe: $backup_parent" >&2
    exit 1
  fi
  resolved_backup_parent="$(cd "$backup_parent" && pwd -P)"
  if [ "$resolved_backup_parent" != "$backup_parent" ]; then
    echo "CocoaPods source backup parent escapes the exact generated path: $resolved_backup_parent" >&2
    exit 1
  fi
  # Do not permit a signal between mktemp creating the candidate and the shell
  # learning its path. EXIT cleanup remains armed; managed signals are restored
  # immediately after the single assignment.
  trap '' HUP INT TERM
  BACKUP_FILE="$(mktemp "$backup_parent/.CioAppDelegateFCM.original.XXXXXX")"
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  if [ "${CIO_LIFECYCLE_INSTRUMENTATION_TEST_FAIL_BACKUP_SETUP:-0}" = 1 ]; then
    echo "forced CocoaPods source backup setup failure" >&2
    exit 1
  fi
  if ! /bin/cp -p "$SOURCE_FILE" "$BACKUP_FILE"; then
    echo "failed to copy CocoaPods source backup" >&2
    exit 1
  fi
  backup_sha="$(shasum -a 256 "$BACKUP_FILE" | awk '{print $1}')"
  if [ "$backup_sha" != "$ORIGINAL_SHA256" ]; then
    echo "CocoaPods source backup hash mismatch: $backup_sha" >&2
    exit 1
  fi
  BACKUP_VERIFIED=1
fi

patch --batch --forward --directory "$(dirname "$SOURCE_FILE")" --strip 0 < "$PATCH_FILE"

actual="$(shasum -a 256 "$SOURCE_FILE" | awk '{print $1}')"
if [ "$actual" != "$PATCHED_SHA256" ]; then
  echo "instrumented Customer.io source hash mismatch: $actual" >&2
  exit 1
fi

echo "verified fixture-only Customer.io source patch: $actual"

if [ "$RESOLUTION" = "cocoapods" ]; then
  receipt="${CIO_LIFECYCLE_INSTRUMENTATION_RECEIPT:-}"
  if [ -z "$receipt" ] || [ -L "$receipt" ] || { [ -e "$receipt" ] && [ ! -f "$receipt" ]; }; then
    echo "CocoaPods instrumentation receipt path is unsafe" >&2
    exit 1
  fi
  receipt_parent="$(dirname "$receipt")"
  if [ ! -d "$receipt_parent" ] || [ -L "$receipt_parent" ]; then
    echo "CocoaPods instrumentation receipt parent is unsafe" >&2
    exit 1
  fi
  /bin/rm -f "$receipt"
  "${BUILD_COMMAND[@]}"
  post_build_sha="$(shasum -a 256 "$SOURCE_FILE" | awk '{print $1}')"
  if [ "$post_build_sha" != "$PATCHED_SHA256" ]; then
    echo "CocoaPods source changed during instrumented build: $post_build_sha" >&2
    exit 1
  fi
  dependency_root="$RESOLVED_ROOT/ios/Pods/CustomerIOMessagingPushFCM"
  patched_tree_sha256="$(python3 "$SNAPSHOT_HELPER" "$dependency_root")"
  if [ "${#patched_tree_sha256}" -ne 64 ]; then
    echo "invalid patched CocoaPods dependency tree hash: $patched_tree_sha256" >&2
    exit 1
  fi
  case "$patched_tree_sha256" in
    *[!0-9a-f]*)
      echo "invalid patched CocoaPods dependency tree hash: $patched_tree_sha256" >&2
      exit 1
      ;;
  esac
  restore_cocoapods_source
  trap - EXIT HUP INT TERM
  pending="$(mktemp "$receipt_parent/.cio-lifecycle-instrumentation.XXXXXX")"
  printf '{"original_sha256":"%s","patch_sha256":"%s","patched_sha256":"%s","patched_tree_sha256":"%s","restored_sha256":"%s"}\n' \
    "$ORIGINAL_SHA256" "$PATCH_SHA256" "$PATCHED_SHA256" "$patched_tree_sha256" "$ORIGINAL_SHA256" > "$pending"
  /bin/mv -f "$pending" "$receipt"
  echo "restored exact CocoaPods Customer.io source: $ORIGINAL_SHA256"
fi
