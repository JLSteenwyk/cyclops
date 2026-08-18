#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_directory="${1:-$project_root/dist/Pocus.app}"
expected_architectures="${POCUS_EXPECTED_ARCHITECTURES:-}"
expected_version="${POCUS_EXPECTED_VERSION:-}"
expected_build_number="${POCUS_EXPECTED_BUILD_NUMBER:-}"
info_plist="$app_directory/Contents/Info.plist"
executable="$app_directory/Contents/MacOS/Pocus"

if [[ ! -d "$app_directory" ]]; then
  echo "App bundle not found: $app_directory" >&2
  exit 1
fi

plutil -lint "$info_plist"

bundle_identifier="$(plutil -extract CFBundleIdentifier raw "$info_plist")"
version="$(plutil -extract CFBundleShortVersionString raw "$info_plist")"
build_number="$(plutil -extract CFBundleVersion raw "$info_plist")"

if [[ "$bundle_identifier" != "com.jlsteenwyk.pocus" ]]; then
  echo "Unexpected bundle identifier: $bundle_identifier" >&2
  exit 1
fi

if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Invalid CFBundleShortVersionString: $version" >&2
  exit 1
fi

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid CFBundleVersion: $build_number" >&2
  exit 1
fi

if [[ -n "$expected_version" && "$version" != "$expected_version" ]]; then
  echo "Expected version $expected_version, found $version" >&2
  exit 1
fi

if [[ -n "$expected_build_number" && "$build_number" != "$expected_build_number" ]]; then
  echo "Expected build $expected_build_number, found $build_number" >&2
  exit 1
fi

for architecture in $expected_architectures; do
  lipo "$executable" -verify_arch "$architecture"
done

codesign --verify --deep --strict --verbose=2 "$app_directory"
codesign_details="$(codesign -dv --verbose=4 "$app_directory" 2>&1)"
if ! grep -q 'flags=.*runtime' <<< "$codesign_details"; then
  echo "Hardened Runtime is not enabled" >&2
  exit 1
fi

printf 'Verified %s\n' "$app_directory"
printf '  bundle: %s\n' "$bundle_identifier"
printf '  version: %s (%s)\n' "$version" "$build_number"
printf '  architectures: %s\n' "$(lipo -archs "$executable")"
