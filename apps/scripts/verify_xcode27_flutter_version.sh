#!/usr/bin/env bash

set -euo pipefail

# Flutter 3.44.8 is the first stable release containing flutter/flutter#188625.
readonly minimum_xcode27_flutter_version="3.44.8"
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_directory
repository_root="$(cd "$script_directory/../.." && pwd)"
readonly repository_root

verify_installed=false
if (( $# == 0 )); then
  :
elif (( $# == 1 )) && [[ "$1" == "--installed" ]]; then
  verify_installed=true
else
  echo "Usage: $0 [--installed]" >&2
  exit 1
fi

pin_files=(
  "$repository_root/apps/flutter_sample_cocoapods/.flutter-version"
  "$repository_root/apps/flutter_sample_spm/.flutter-version"
)
readonly -a pin_files

read_version() {
  local pin_file="$1"
  local version

  if [[ ! -f "$pin_file" ]]; then
    echo "Missing Flutter version pin: $pin_file" >&2
    return 1
  fi

  version="$(<"$pin_file")"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Flutter version pin must be an exact stable x.y.z version: $pin_file ($version)" >&2
    return 1
  fi

  printf '%s\n' "$version"
}

version_is_at_least() {
  local actual="$1"
  local minimum="$2"
  local actual_major actual_minor actual_patch
  local minimum_major minimum_minor minimum_patch

  IFS=. read -r actual_major actual_minor actual_patch <<< "$actual"
  IFS=. read -r minimum_major minimum_minor minimum_patch <<< "$minimum"

  actual_major=$((10#$actual_major))
  actual_minor=$((10#$actual_minor))
  actual_patch=$((10#$actual_patch))
  minimum_major=$((10#$minimum_major))
  minimum_minor=$((10#$minimum_minor))
  minimum_patch=$((10#$minimum_patch))

  ((
    actual_major > minimum_major ||
      (actual_major == minimum_major && actual_minor > minimum_minor) ||
      (actual_major == minimum_major && actual_minor == minimum_minor && actual_patch >= minimum_patch)
  ))
}

resolved_version=""
for pin_file in "${pin_files[@]}"; do
  version="$(read_version "$pin_file")"
  if ! version_is_at_least "$version" "$minimum_xcode27_flutter_version"; then
    echo "Xcode 27 requires Flutter $minimum_xcode27_flutter_version or later; $pin_file pins $version" >&2
    exit 1
  fi
  if [[ -n "$resolved_version" && "$version" != "$resolved_version" ]]; then
    echo "Xcode 27 Flutter pins must match; found $resolved_version and $version" >&2
    exit 1
  fi
  resolved_version="$version"
done

if [[ "$verify_installed" == true ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Flutter is not installed or is not available on PATH" >&2
    exit 1
  fi
  flutter_path="$(command -v flutter)"
  installed_version="$("$flutter_path" --version --machine | awk -F '"' '/"frameworkVersion"/ { print $4; exit }')"
  if [[ -z "$installed_version" ]]; then
    echo "Unable to determine the installed Flutter version from $flutter_path" >&2
    exit 1
  fi
  if [[ "$installed_version" != "$resolved_version" ]]; then
    echo "Installed Flutter $installed_version at $flutter_path does not match the Xcode 27 pin $resolved_version" >&2
    exit 1
  fi
  echo "Xcode 27 Flutter toolchain verified: $resolved_version at $flutter_path (minimum $minimum_xcode27_flutter_version)"
else
  echo "Xcode 27 Flutter pins verified: $resolved_version (minimum $minimum_xcode27_flutter_version)"
fi
