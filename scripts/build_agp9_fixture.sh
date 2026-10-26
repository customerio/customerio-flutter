#!/bin/bash

# Builds a fresh `flutter create` Android app that depends on this plugin, with the AGP 9,
# Gradle and KGP versions the installed Flutter's template picks. The sample apps stay on
# AGP 8, so this is what notices the plugin breaking under AGP 9 or built-in Kotlin.
#
# Usage: ./scripts/build_agp9_fixture.sh <fixture-dir> [built-in-kotlin true|false] [new-dsl true|false]
#
# Flutter's template sets android.builtInKotlin=false and android.newDsl=false; passing true
# switches them to AGP 9's own defaults. Built-in Kotlin needs Flutter 3.47 or later.

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 <fixture-dir> [built-in-kotlin true|false] [new-dsl true|false]" >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$1"
built_in_kotlin="${2:-false}"
new_dsl="${3:-false}"

for value in "$built_in_kotlin" "$new_dsl"; do
  if [[ "$value" != "true" && "$value" != "false" ]]; then
    echo "❌ Error: expected true or false, got '$value'" >&2
    exit 2
  fi
done

rm -rf "$fixture_dir"
flutter create --org io.customer.ci --project-name cio_agp9_fixture \
  --platforms android --android-language kotlin "$fixture_dir"
cd "$fixture_dir"
flutter pub add "customer_io:{path: $repository_root}"

properties="android/gradle.properties"
set_property() {
  local key=$1 value=$2
  if grep -q "^$key=" "$properties"; then
    sed -i.bak "s|^$key=.*|$key=$value|" "$properties" && rm "$properties.bak"
  else
    echo "$key=$value" >> "$properties"
  fi
}
set_property android.builtInKotlin "$built_in_kotlin"
set_property android.newDsl "$new_dsl"

agp_version="$(sed -nE 's/.*"com\.android\.application"\) version "([^"]+)".*/\1/p' android/settings.gradle.kts)"
kgp_version="$(sed -nE 's/.*"org\.jetbrains\.kotlin\.android"\) version "([^"]+)".*/\1/p' android/settings.gradle.kts)"
gradle_version="$(sed -nE 's/^distributionUrl=.*gradle-([^-]+)-.*/\1/p' android/gradle/wrapper/gradle-wrapper.properties)"
echo "Fixture toolchain: AGP $agp_version, Gradle $gradle_version, KGP $kgp_version, builtInKotlin=$built_in_kotlin, newDsl=$new_dsl"
if [[ "${agp_version%%.*}" -lt 9 ]]; then
  echo "❌ Error: the Flutter template picked AGP $agp_version; this check needs AGP 9 or later" >&2
  exit 1
fi

build_log="$(mktemp)"
trap 'rm -f "$build_log"' EXIT
flutter build apk --release 2>&1 | tee "$build_log"

# With AGP 9, Flutter lists every plugin that still applies KGP. customer_io must not be one.
if grep -E "plugins that apply Kotlin Gradle Plugin \(KGP\):.*\bcustomer_io\b" "$build_log"; then
  echo "❌ Error: customer_io applies the Kotlin Gradle Plugin; migrate it to built-in Kotlin" >&2
  exit 1
fi

# Reuses the Gradle daemon the build above started instead of starting a second JVM.
(cd android && ./gradlew :customer_io:testDebugUnitTest)

echo "✅ customer_io builds under AGP $agp_version (builtInKotlin=$built_in_kotlin, newDsl=$new_dsl)"
