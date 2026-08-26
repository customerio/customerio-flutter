#!/usr/bin/env bash

set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAESTRO_DIR="$APP_DIR/.maestro"
APP_ID="io.customer.testbed.flutter.spm"
MOBILE_E2E_REF="7c7912eedc96fdd623dcb8a7c0d9111feae56d39"
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ "$DEVELOPER_DIR" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR

if [[ -f "$MAESTRO_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$MAESTRO_DIR/.env"
  set +a
fi
: "${MAESTRO_APP_API_KEY:=${MAESTRO_EXT_API_KEY:-}}"
: "${MAESTRO_EXT_API_BASE_URL:=https://api.customer.io/v1}"
export MAESTRO_APP_API_KEY MAESTRO_EXT_API_BASE_URL

die() {
  echo "error: $*" >&2
  exit 2
}

for required_command in curl flutter git jq maestro plutil python3 ruby xcodebuild xcrun; do
  command -v "$required_command" >/dev/null 2>&1 || die "required command '$required_command' is not installed"
done

"$APP_DIR/../scripts/verify_xcode27_flutter_version.sh" --installed
maestro_version="$(MAESTRO_CLI_NO_ANALYTICS=1 maestro --version | tr -d '\r')"
[[ "$maestro_version" == "2.8.0" ]] || die "Maestro 2.8.0 is required; found '$maestro_version'"

[[ -n "${MAESTRO_APP_API_KEY:-}" ]] || die "MAESTRO_APP_API_KEY is missing; set it or create .maestro/.env"
[[ "$MAESTRO_APP_API_KEY" != *paste-* ]] || die "MAESTRO_APP_API_KEY still contains a placeholder"
[[ -n "${FLUTTER_CDP_API_KEY:-}" ]] || die "FLUTTER_CDP_API_KEY is missing; set it or create .maestro/.env"
[[ "$FLUTTER_CDP_API_KEY" != *paste-* ]] || die "FLUTTER_CDP_API_KEY still contains a placeholder"

backend_status="$(curl -sS --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 \
  -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $MAESTRO_APP_API_KEY" \
  "$MAESTRO_EXT_API_BASE_URL/customers?email=maestro-doctor-no-match%40cio.test" || true)"
[[ "$backend_status" == "200" ]] || die "Customer.io App API preflight returned HTTP ${backend_status:-unreachable}"

campaign_response="$(curl -sS --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 \
  -w $'\n%{http_code}' \
  -H "Authorization: Bearer $MAESTRO_APP_API_KEY" \
  "$MAESTRO_EXT_API_BASE_URL/campaigns/18" || true)"
campaign_status="${campaign_response##*$'\n'}"
campaign_body="${campaign_response%$'\n'*}"
[[ "$campaign_status" == "200" ]] || \
  die "App API key cannot access campaign 18 in the Mobile: Flutter workspace (HTTP ${campaign_status:-unreachable})"
campaign_name="$(printf '%s' "$campaign_body" | jq -r '.campaign.name // .name // empty' 2>/dev/null || true)"
campaign_event="$(printf '%s' "$campaign_body" | jq -r '.campaign.event_name // .event_name // empty' 2>/dev/null || true)"
[[ "$campaign_name" == "send_push" && "$campaign_event" == "send_push" ]] || \
  die "campaign 18 is not the expected Mobile: Flutter send_push automation"

device_id="${E2E_DEVICE_ID:-}"
simulator_name="${E2E_SIMULATOR_NAME:-}"
if [[ -z "$device_id" && -n "$simulator_name" ]]; then
  device_id="$(xcrun simctl list devices available -j | jq -r --arg name "$simulator_name" \
    '[.devices[][] | select(.name == $name)][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices booted -j | jq -r \
    '[.devices[][] | select(.state == "Booted") | select(.name | startswith("iPhone"))][0].udid // empty')"
fi
if [[ -z "$device_id" ]]; then
  simulator_name="${simulator_name:-iPhone 17 Pro}"
  device_id="$(xcrun simctl list devices available -j | jq -r --arg name "$simulator_name" \
    '[.devices[][] | select(.name == $name)][0].udid // empty')"
fi
[[ -n "$device_id" ]] || die "no available iPhone simulator; set E2E_DEVICE_ID or E2E_SIMULATOR_NAME"
simulator_started_by_runner=false
if ! xcrun simctl list devices booted -j | jq -e --arg id "$device_id" \
  'any(.devices[][]; .udid == $id and .state == "Booted")' >/dev/null; then
  xcrun simctl boot "$device_id"
  simulator_started_by_runner=true
fi
xcrun simctl bootstatus "$device_id" -b

temp_base="${TMPDIR:-/tmp}"
temp_base="${temp_base%/}"
run_root="$(mktemp -d "$temp_base/cio-flutter-remote-push.XXXXXX")"
harness="$run_root/mobile-e2e"
derived_data="$run_root/derived-data"
artifacts="$run_root/maestro-artifacts"
artifact_export_dir="${CIO_E2E_ARTIFACT_DIR:-}"
dotenv="$APP_DIR/.env"
native_env="$APP_DIR/ios/Env.swift"
dotenv_backup="$run_root/dotenv.original"
native_env_backup="$run_root/Env.swift.original"
lockfile="$APP_DIR/pubspec.lock"
lockfile_backup="$run_root/pubspec.lock.original"
had_dotenv=false
had_native_env=false
config_replacement_started=false
installed_app=false
cp "$lockfile" "$lockfile_backup"

# shellcheck disable=SC2329
cleanup() {
  set +e
  if [[ -d "$harness" && -d "$artifacts" ]]; then
    python3 "$harness/scripts/redact_artifacts.py" "$artifacts" >/dev/null 2>&1 || true
  fi
  if [[ "$installed_app" == true && "${CIO_E2E_KEEP_APP:-false}" != "true" ]]; then
    xcrun simctl terminate "$device_id" "$APP_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$device_id" "$APP_ID" >/dev/null 2>&1 || true
  fi
  if [[ "$simulator_started_by_runner" == true ]]; then
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
  fi
  if [[ "$config_replacement_started" == true ]]; then
    if [[ "$had_dotenv" == true ]]; then
      cp "$dotenv_backup" "$dotenv"
    else
      rm -f -- "$dotenv"
    fi
    if [[ "$had_native_env" == true ]]; then
      cp "$native_env_backup" "$native_env"
    else
      rm -f -- "$native_env"
    fi
    cp "$lockfile_backup" "$lockfile"
  fi
  case "$run_root" in
    "$temp_base"/cio-flutter-remote-push.*) rm -rf -- "$run_root" ;;
  esac
}
trap cleanup EXIT

if [[ -f "$dotenv" ]]; then
  cp "$dotenv" "$dotenv_backup"
  had_dotenv=true
fi
if [[ -f "$native_env" ]]; then
  cp "$native_env" "$native_env_backup"
  had_native_env=true
fi
config_replacement_started=true
printf 'SITE_ID=\nCDP_API_KEY=%s\nWORKSPACE_NAME=Mobile: Flutter\nSDK_VERSION=\n' "$FLUTTER_CDP_API_KEY" >"$dotenv"
printf 'import Foundation\n\nclass Env {\n    static let cdpApiKey: String = "%s"\n}\n' "$FLUTTER_CDP_API_KEY" >"$native_env"
export IOS_CDP_API_KEY="$FLUTTER_CDP_API_KEY"

git init -q "$harness"
git -C "$harness" remote add origin https://github.com/customerio/mobile-e2e.git
git -C "$harness" fetch -q --depth 1 origin "$MOBILE_E2E_REF"
git -C "$harness" checkout -q --detach FETCH_HEAD
[[ "$(git -C "$harness" rev-parse HEAD)" == "$MOBILE_E2E_REF" ]] || \
  die "mobile-e2e harness checkout does not match the reviewed commit"
cp "$MAESTRO_DIR/remote_push.yaml" "$harness/flows/flutter_remote_push.yaml"

cd "$APP_DIR"
flutter clean
flutter pub get
flutter build ios --simulator --debug --no-pub
xcodebuild -quiet \
  -project ios/Runner.xcodeproj \
  -scheme Runner \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_data" \
  CIO_LIFECYCLE_INFOPLIST_SUFFIX=-Scene \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  build >"$run_root/xcodebuild.log" 2>&1 || {
    if ruby -e '
      key = ENV.fetch("IOS_CDP_API_KEY")
      path = ARGV[0]
      File.write(path, File.read(path).gsub(key, "[REDACTED]"))
    ' "$run_root/xcodebuild.log"; then
      tail -100 "$run_root/xcodebuild.log" >&2
    else
      echo "Flutter FCM sample build failed; log withheld because credential redaction failed" >&2
    fi
    die "Flutter FCM sample build failed"
  }
echo "Flutter FCM sample build succeeded"

app_path="$derived_data/Build/Products/Debug-iphonesimulator/Runner.app"
[[ -d "$app_path" ]] || die "built sample app was not found at $app_path"
built_dotenv="$app_path/Frameworks/App.framework/flutter_assets/.env"
[[ -f "$built_dotenv" ]] || die "built sample app is missing its Flutter workspace configuration"
grep -Fqx "CDP_API_KEY=$FLUTTER_CDP_API_KEY" "$built_dotenv" || \
  die "built sample app does not contain the configured Flutter CDP source key"
simulator_entitlements="$(find "$derived_data/Build/Intermediates.noindex" -name 'Runner.app-Simulated.xcent' -print -quit)"
[[ -f "$simulator_entitlements" ]] || die "built sample app simulator entitlements were not found"
[[ "$(plutil -extract aps-environment raw "$simulator_entitlements")" == "development" ]] || \
  die "built sample app is missing the development APNs simulator entitlement"
xcrun simctl uninstall "$device_id" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$device_id" "$app_path"
installed_app=true

run_id="flutter-$(date +%s)-$(python3 -c 'import secrets; print(secrets.token_hex(4))')"
run_email="maestro+e2e-${run_id}@cio.test"
run_started_at_seconds="$(date +%s)"
identify_payload="$(jq -nc --arg id "$run_email" \
  '{userId: $id, traits: {name: "Maestro Campaign Tester"}}')"
identify_status="$(curl -sS --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 \
  -o "$run_root/identify-response.json" -w '%{http_code}' \
  -u "$FLUTTER_CDP_API_KEY:" \
  -H 'content-type: application/json' \
  -d "$identify_payload" \
  https://cdp.customer.io/v1/identify || true)"
[[ "$identify_status" == "200" ]] || die "Flutter test-profile setup failed (HTTP ${identify_status:-unreachable})"
[[ "$(jq -r '.success // false' "$run_root/identify-response.json")" == "true" ]] || \
  die "Flutter test-profile setup was rejected"

mkdir -p "$artifacts"
set +e
maestro --device "$device_id" test \
  --debug-output "$artifacts" \
  --flatten-debug-output \
  -e "APP_ID=$APP_ID" \
  -e "MAESTRO_APP_API_KEY=$MAESTRO_APP_API_KEY" \
  -e "MAESTRO_EXT_API_BASE_URL=$MAESTRO_EXT_API_BASE_URL" \
  -e "RUN_EMAIL=$run_email" \
  -e "RUN_ID=$run_id" \
  -e "RUN_STARTED_AT_SECONDS=$run_started_at_seconds" \
  "$harness/flows/flutter_remote_push.yaml"
result=$?
set -e

python3 "$harness/scripts/redact_artifacts.py" "$artifacts"
python3 "$harness/scripts/redact_artifacts.py" "$artifacts" --check
if [[ -n "$artifact_export_dir" ]]; then
  mkdir -p "$artifact_export_dir"
  cp -R "$artifacts/." "$artifact_export_dir/"
fi
exit "$result"
