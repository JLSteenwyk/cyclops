#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_directory="${1:-$project_root/dist/Pocus.app}"
expected_architectures="${POCUS_EXPECTED_ARCHITECTURES:-}"
expected_version="${POCUS_EXPECTED_VERSION:-}"
expected_build_number="${POCUS_EXPECTED_BUILD_NUMBER:-}"
expected_team_id="${POCUS_EXPECTED_TEAM_ID:-}"
info_plist="$app_directory/Contents/Info.plist"
executable="$app_directory/Contents/MacOS/Pocus"
sparkle_framework="$app_directory/Contents/Frameworks/Sparkle.framework"
require_hardened_runtime="${POCUS_REQUIRE_HARDENED_RUNTIME:-0}"
require_production_signing="${POCUS_REQUIRE_PRODUCTION_SIGNING:-0}"

verify_production_signature() {
  local component="$1"
  local details
  local team_id
  details="$(codesign -dv --verbose=4 "$component" 2>&1)"

  if grep -q '^Signature=adhoc$' <<< "$details"; then
    echo "$component is ad-hoc signed; a Developer ID signature is required" >&2
    exit 1
  fi
  if ! grep -q '^Authority=Developer ID Application:' <<< "$details"; then
    echo "$component is not signed with a Developer ID Application certificate" >&2
    exit 1
  fi
  if ! grep -q '^Timestamp=' <<< "$details"; then
    echo "$component does not contain a secure signing timestamp" >&2
    exit 1
  fi
  if [[ "$require_hardened_runtime" == "1" ]] && ! grep -q 'flags=.*runtime' <<< "$details"; then
    echo "Hardened Runtime is not enabled for $component" >&2
    exit 1
  fi

  team_id="$(sed -n 's/^TeamIdentifier=//p' <<< "$details")"
  if [[ -z "$team_id" || "$team_id" == "not set" ]]; then
    echo "$component does not contain a signing team identifier" >&2
    exit 1
  fi
  if [[ -n "$expected_team_id" && "$team_id" != "$expected_team_id" ]]; then
    echo "Expected signing team $expected_team_id, found $team_id on $component" >&2
    exit 1
  fi
}

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
if [[ "$require_hardened_runtime" == "1" ]]; then
  if ! grep -q 'flags=.*runtime' <<< "$codesign_details"; then
    echo "Hardened Runtime is not enabled" >&2
    exit 1
  fi
fi

if [[ "$require_production_signing" == "1" ]]; then
  verify_production_signature "$app_directory"
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
  if [[ "$require_production_signing" == "1" ]]; then
    verify_production_signature "$sparkle_component"
  fi
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
if [[ "$(plutil -extract SUAutomaticallyUpdate raw "$info_plist")" != "false" ]]; then
  echo "Sparkle automatic installation must be disabled by default" >&2
  exit 1
fi
if [[ "$(plutil -extract SUScheduledCheckInterval raw "$info_plist")" != "86400" ]]; then
  echo "Sparkle scheduled checks must use the daily 86400-second interval" >&2
  exit 1
fi
if plutil -extract SUEnableAutomaticChecks raw "$info_plist" >/dev/null 2>&1; then
  echo "SUEnableAutomaticChecks must be absent so Sparkle uses its standard consent flow" >&2
  exit 1
fi

printf 'Verified %s\n' "$app_directory"
printf '  bundle: %s\n' "$bundle_identifier"
printf '  version: %s (%s)\n' "$version" "$build_number"
printf '  architectures: %s\n' "$(lipo -archs "$executable")"
printf '  update feed: %s\n' "$feed_url"
