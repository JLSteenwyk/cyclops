#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_directory="${1:-$project_root/dist/Pocus.app}"
expected_architectures="${POCUS_EXPECTED_ARCHITECTURES:-}"
expected_version="${POCUS_EXPECTED_VERSION:-}"
expected_build_number="${POCUS_EXPECTED_BUILD_NUMBER:-}"
info_plist="$app_directory/Contents/Info.plist"
executable="$app_directory/Contents/MacOS/Pocus"
sparkle_framework="$app_directory/Contents/Frameworks/Sparkle.framework"

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
if [[ "${POCUS_REQUIRE_HARDENED_RUNTIME:-0}" == "1" ]]; then
  if ! grep -q 'flags=.*runtime' <<< "$codesign_details"; then
    echo "Hardened Runtime is not enabled" >&2
    exit 1
  fi
fi

if [[ ! -d "$sparkle_framework" ]]; then
  echo "Sparkle.framework is not embedded" >&2
  exit 1
fi

if ! otool -L "$executable" | grep -q '@rpath/Sparkle.framework/Versions/B/Sparkle'; then
  echo "Pocus is not linked to the embedded Sparkle framework" >&2
  exit 1
fi

if ! otool -l "$executable" | grep -A2 LC_RPATH | grep -q '@executable_path/../Frameworks'; then
  echo "Pocus does not contain the Sparkle runtime search path" >&2
  exit 1
fi

for sparkle_component in \
  "$sparkle_framework/Versions/B/Autoupdate" \
  "$sparkle_framework/Versions/B/XPCServices/Downloader.xpc" \
  "$sparkle_framework/Versions/B/XPCServices/Installer.xpc" \
  "$sparkle_framework/Versions/B/Updater.app" \
  "$sparkle_framework"; do
  codesign --verify --strict --verbose=2 "$sparkle_component"
done

feed_url="$(plutil -extract SUFeedURL raw "$info_plist")"
public_key="$(plutil -extract SUPublicEDKey raw "$info_plist")"
if [[ ! "$feed_url" =~ ^https:// && ! "$feed_url" =~ ^http://(127\.0\.0\.1|localhost)(:[0-9]+)?/ ]]; then
  echo "Sparkle feed URL is neither HTTPS nor a localhost fixture: $feed_url" >&2
  exit 1
fi
if [[ -z "$public_key" ]]; then
  echo "Sparkle public key is missing" >&2
  exit 1
fi
if [[ "$(plutil -extract SURequireSignedFeed raw "$info_plist")" != "true" ]]; then
  echo "Signed Sparkle feeds are not required" >&2
  exit 1
fi
if [[ "$(plutil -extract SUVerifyUpdateBeforeExtraction raw "$info_plist")" != "true" ]]; then
  echo "Sparkle is not configured to verify updates before extraction" >&2
  exit 1
fi

printf 'Verified %s\n' "$app_directory"
printf '  bundle: %s\n' "$bundle_identifier"
printf '  version: %s (%s)\n' "$version" "$build_number"
printf '  architectures: %s\n' "$(lipo -archs "$executable")"
printf '  update feed: %s\n' "$feed_url"
