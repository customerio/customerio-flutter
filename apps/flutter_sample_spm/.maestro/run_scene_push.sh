#!/usr/bin/env bash

set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_ID="io.customer.testbed.flutter.spm"
flow_log=""
flow_pid=""
installed_app=false
config_backup=""
config_replacement_started=false
had_dotenv=false
had_native_env=false
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ "$DEVELOPER_DIR" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR

for command in flutter jq maestro xcodebuild xcrun; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "error: required command '$command' is not installed" >&2
    exit 2
  }
done
maestro_version="$(MAESTRO_CLI_NO_ANALYTICS=1 maestro --version | tr -d '\r')"
if [[ "$maestro_version" != '2.8.0' ]]; then
  echo "error: Maestro 2.8.0 is required; found '$maestro_version'" >&2
  exit 2
fi

runtime_major="${E2E_IOS_RUNTIME_MAJOR:-27}"
runtime_fragment=".iOS-${runtime_major}-"
simulator_devices="$(xcrun simctl list devices available -j)"
device_id="${E2E_DEVICE_ID:-}"
simulator_name="${E2E_SIMULATOR_NAME:-}"
if [[ -z "$device_id" && -n "$simulator_name" ]]; then
  device_id="$(jq -r --arg name "$simulator_name" --arg runtime "$runtime_fragment" \
    '[.devices | to_entries[] | select(.key | contains($runtime)) | .value[] | select(.name == $name)][0].udid // empty' \
    <<< "$simulator_devices")"
fi
if [[ -z "$device_id" && -z "$simulator_name" ]]; then
  device_id="$(jq -r --arg runtime "$runtime_fragment" \
    '[.devices | to_entries[] | select(.key | contains($runtime)) | .value[] | select(.state == "Booted") | select(.name | startswith("iPhone"))][0].udid // empty' \
    <<< "$simulator_devices")"
fi
if [[ -z "$device_id" ]]; then
  simulator_name="${simulator_name:-iPhone 17 Pro}"
  device_id="$(jq -r --arg name "$simulator_name" --arg runtime "$runtime_fragment" \
    '[.devices | to_entries[] | select(.key | contains($runtime)) | .value[] | select(.name == $name)][0].udid // empty' \
    <<< "$simulator_devices")"
  if [[ -z "$device_id" ]]; then
    echo "error: no available '$simulator_name' simulator on iOS $runtime_major; set E2E_DEVICE_ID, E2E_SIMULATOR_NAME, or E2E_IOS_RUNTIME_MAJOR" >&2
    exit 2
  fi
fi
runtime_id="$(jq -r --arg id "$device_id" \
  '[.devices | to_entries[] | select(any(.value[]; .udid == $id))][0].key // empty' \
  <<< "$simulator_devices")"
if [[ "$runtime_id" != *"$runtime_fragment"* ]]; then
  echo "error: selected simulator runtime '$runtime_id' is not iOS $runtime_major" >&2
  exit 2
fi
simulator_started_by_runner=false

cd "$APP_DIR"
cleanup() {
  if [[ -n "$flow_pid" ]]; then
    kill "$flow_pid" >/dev/null 2>&1 || true
    wait "$flow_pid" 2>/dev/null || true
  fi
  if [[ -n "$flow_log" && -z "${RUNNER_TEMP:-}" ]]; then
    rm -f "$flow_log"
  fi
  if [[ "$installed_app" == true ]]; then
    xcrun simctl terminate "$device_id" "$APP_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$device_id" "$APP_ID" >/dev/null 2>&1 || true
  fi
  if [[ "$simulator_started_by_runner" == true ]]; then
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
  fi
  if [[ -n "$config_backup" ]]; then
    if [[ "$config_replacement_started" == true ]]; then
      if [[ "$had_dotenv" == true ]]; then
        cp "$config_backup/dotenv" .env
      else
        rm -f .env
      fi
      if [[ "$had_native_env" == true ]]; then
        cp "$config_backup/Env.swift" ios/Env.swift
      else
        rm -f ios/Env.swift
      fi
      cp "$config_backup/pubspec.lock" pubspec.lock
    fi
    find "$config_backup" -depth -delete
  fi
}
trap cleanup EXIT

if ! jq -e --arg id "$device_id" \
  'any(.devices[][]; .udid == $id and .state == "Booted")' <<< "$simulator_devices" >/dev/null; then
  xcrun simctl boot "$device_id"
  simulator_started_by_runner=true
fi
xcrun simctl bootstatus "$device_id" -b

run_notification_flow() {
  local flow="$1"
  local payload="$2"
  local ready=false
  local status=0
  local flow_name="${flow##*/}"
  local maestro_args=(--device "$device_id" test "$flow")

  flow_name="${flow_name%.yaml}"
  if [[ -n "${RUNNER_TEMP:-}" ]]; then
    maestro_args=(
      --device "$device_id"
      test
      --debug-output "$RUNNER_TEMP/flutter_sample_spm-maestro-$flow_name"
      --flatten-debug-output
      "$flow"
    )
  fi

  # Injection must happen after Maestro's iOS driver is active; starting a second
  # Maestro session after injection dismisses the notification banner.
  if [[ -n "${RUNNER_TEMP:-}" ]]; then
    flow_log="$RUNNER_TEMP/flutter_sample_spm-maestro-$flow_name.log"
  else
    flow_log="$(mktemp "${TMPDIR:-/tmp}/cio-flutter-maestro-flow.XXXXXX")"
  fi
  : > "$flow_log"
  maestro "${maestro_args[@]}" > >(tee "$flow_log") 2>&1 &
  flow_pid=$!

  for _ in {1..240}; do
    if grep -q 'Press Home key.*COMPLETED' "$flow_log"; then
      ready=true
      break
    fi
    if ! kill -0 "$flow_pid" >/dev/null 2>&1; then
      if wait "$flow_pid"; then
        echo "error: Maestro completed before reaching the Home screen" >&2
      else
        status=$?
        echo "error: Maestro exited before reaching the Home screen (status $status)" >&2
      fi
      flow_pid=""
      return 1
    fi
    sleep 0.5
  done

  if [[ "$ready" != true ]]; then
    echo "error: Maestro did not reach the Home screen before notification injection" >&2
    return 1
  fi

  local push_output
  if ! push_output="$(xcrun simctl push "$device_id" "$APP_ID" "$payload" 2>&1)"; then
    printf '%s\n' "$push_output" >&2
    if grep -q 'UNErrorDomain.*2003\|Source is not authorized' <<< "$push_output"; then
      echo "error: simulator notification authorization was not granted; notification routing was not exercised" >&2
    else
      echo "error: simctl could not inject the notification fixture" >&2
    fi
    return 1
  fi
  printf '%s\n' "$push_output"
  if ! wait "$flow_pid"; then
    flow_pid=""
    return 1
  fi
  flow_pid=""
  if [[ -z "${RUNNER_TEMP:-}" ]]; then
    rm -f "$flow_log"
  fi
  flow_log=""
}

app_path="${CIO_E2E_APP_PATH:-}"
if [[ -z "$app_path" ]]; then
  config_backup="$(mktemp -d "${TMPDIR:-/tmp}/cio-flutter-scene-config.XXXXXX")"
  cp pubspec.lock "$config_backup/pubspec.lock"
  if [[ -f .env ]]; then
    cp .env "$config_backup/dotenv"
    had_dotenv=true
  fi
  if [[ -f ios/Env.swift ]]; then
    cp ios/Env.swift "$config_backup/Env.swift"
    had_native_env=true
  fi
  config_replacement_started=true
  cp .env.example .env
  cp ios/Env.swift.example ios/Env.swift
  flutter clean
  flutter pub get
  flutter build ios --simulator --debug --no-pub

  derived_data="${CIO_E2E_DERIVED_DATA:-$APP_DIR/build/maestro-scene-derived-data}"
  xcodebuild -quiet \
    -project ios/Runner.xcodeproj \
    -scheme Runner \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$derived_data" \
    CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene \
    build

  app_path="$derived_data/Build/Products/Debug-iphonesimulator/Runner.app"
fi
test -d "$app_path"
xcrun simctl uninstall "$device_id" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app_path"
installed_app=true

prepare_args=(--device "$device_id" test .maestro/scene_push_prepare.yaml)
if [[ -n "${RUNNER_TEMP:-}" ]]; then
  prepare_args=(
    --device "$device_id"
    test
    --debug-output "$RUNNER_TEMP/flutter_sample_spm-maestro-scene_push_prepare"
    --flatten-debug-output
    .maestro/scene_push_prepare.yaml
  )
fi
maestro "${prepare_args[@]}"
xcrun simctl terminate "$device_id" "$APP_ID"
terminated=false
for _ in {1..20}; do
  if launch_jobs="$(xcrun simctl spawn "$device_id" launchctl list 2>/dev/null)"; then
    if ! grep -Fq "$APP_ID" <<< "$launch_jobs"; then
      terminated=true
      break
    fi
  fi
  sleep 0.25
done
if [[ "$terminated" != true ]]; then
  echo "error: app was still running after simctl terminate; cold notification routing was not exercised" >&2
  exit 1
fi
run_notification_flow .maestro/scene_push_open.yaml .maestro/fixtures/customerio_scene_settings.apns
