#!/usr/bin/env bash

# Applies the fixture-only raw-launch probe to the exact Customer.io iOS 4.7.2
# FCM source resolved by CocoaPods or SwiftPM. The published wrapper and package
# sources remain untouched. Both the input and result are hash-locked so the
# instrumentation fails closed if dependency resolution changes.

set -euo pipefail

RESOLUTION="${1:-}"
GENERATED_ROOT="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATCH_FILE="$SCRIPT_DIR/../lifecycle_fixture/customerio-ios-fcm-4.7.2-raw-launch.patch"
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
case "$actual" in
  "$ORIGINAL_SHA256")
    patch --batch --forward --directory "$(dirname "$SOURCE_FILE")" --strip 0 < "$PATCH_FILE"
    ;;
  "$PATCHED_SHA256")
    ;;
  *)
    echo "unexpected Customer.io source hash: $actual" >&2
    exit 1
    ;;
esac

actual="$(shasum -a 256 "$SOURCE_FILE" | awk '{print $1}')"
if [ "$actual" != "$PATCHED_SHA256" ]; then
  echo "instrumented Customer.io source hash mismatch: $actual" >&2
  exit 1
fi

echo "verified fixture-only Customer.io source patch: $actual"
