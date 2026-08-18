#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
info_plist="$project_root/Resources/Info.plist"
version="${POCUS_VERSION:-$(plutil -extract CFBundleShortVersionString raw "$info_plist")}"
build_number="${POCUS_BUILD_NUMBER:-}"
feed_url="${POCUS_FEED_URL:-}"
download_base_url="${POCUS_DOWNLOAD_BASE_URL:-}"
signing_identity="${POCUS_CODE_SIGN_IDENTITY:-}"
sparkle_key_file="${POCUS_SPARKLE_PRIVATE_KEY_FILE:-}"
notary_profile="${POCUS_NOTARY_KEYCHAIN_PROFILE:-}"
notary_keychain="${POCUS_NOTARY_KEYCHAIN:-}"
release_notes_file="${POCUS_RELEASE_NOTES_FILE:-}"
expected_team_id="${POCUS_EXPECTED_TEAM_ID:-}"

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "$name is required for a production release" >&2
    exit 1
  fi
}

require_value POCUS_BUILD_NUMBER "$build_number"
require_value POCUS_FEED_URL "$feed_url"
require_value POCUS_DOWNLOAD_BASE_URL "$download_base_url"
require_value POCUS_CODE_SIGN_IDENTITY "$signing_identity"
require_value POCUS_SPARKLE_PRIVATE_KEY_FILE "$sparkle_key_file"
require_value POCUS_NOTARY_KEYCHAIN_PROFILE "$notary_profile"
require_value POCUS_EXPECTED_TEAM_ID "$expected_team_id"

if [[ "$signing_identity" == "-" ]]; then
  echo "Ad-hoc signing is not allowed for production releases" >&2
  exit 1
fi
if [[ ! "$feed_url" =~ ^https:// || "$feed_url" == *updates.invalid* ]]; then
  echo "POCUS_FEED_URL must be a real public HTTPS appcast URL" >&2
  exit 1
fi
if [[ ! "$download_base_url" =~ ^https:// ]]; then
  echo "POCUS_DOWNLOAD_BASE_URL must use HTTPS" >&2
  exit 1
fi
if [[ ! -s "$sparkle_key_file" ]]; then
  echo "Sparkle private key file is missing or empty" >&2
  exit 1
fi

expected_sparkle_public_key="$(plutil -extract SUPublicEDKey raw "$info_plist")"
actual_sparkle_public_key="$(swift "$project_root/scripts/sparkle-public-key.swift" "$sparkle_key_file")"
if [[ "$actual_sparkle_public_key" != "$expected_sparkle_public_key" ]]; then
  echo "Sparkle private key does not match SUPublicEDKey" >&2
  exit 1
fi

release_directory="$project_root/dist/release"
if [[ -e "$release_directory" ]]; then
  previous_release="$project_root/dist/release.previous-$(date +%Y%m%d-%H%M%S)"
  mv "$release_directory" "$previous_release"
  printf 'Preserved previous release output at %s\n' "$previous_release"
fi
mkdir -p "$release_directory"

env \
  POCUS_VERSION="$version" \
  POCUS_BUILD_NUMBER="$build_number" \
  POCUS_ARCHITECTURES="arm64 x86_64" \
  POCUS_FEED_URL="$feed_url" \
  POCUS_CODE_SIGN_IDENTITY="$signing_identity" \
  "$project_root/scripts/build-app.sh"

env \
  POCUS_EXPECTED_VERSION="$version" \
  POCUS_EXPECTED_BUILD_NUMBER="$build_number" \
  POCUS_EXPECTED_ARCHITECTURES="arm64 x86_64" \
  POCUS_EXPECTED_TEAM_ID="$expected_team_id" \
  POCUS_REQUIRE_HARDENED_RUNTIME=1 \
  POCUS_REQUIRE_PRODUCTION_SIGNING=1 \
  "$project_root/scripts/verify-app.sh" "$project_root/dist/Pocus.app"

dmg_path="$release_directory/Pocus-$version.dmg"
POCUS_VERSION="$version" "$project_root/scripts/create-dmg.sh" \
  "$project_root/dist/Pocus.app" \
  "$dmg_path"
codesign --force --timestamp --sign "$signing_identity" "$dmg_path"
codesign --verify --strict --verbose=2 "$dmg_path"
dmg_signing_details="$(codesign -dv --verbose=4 "$dmg_path" 2>&1)"
if ! grep -q '^Authority=Developer ID Application:' <<< "$dmg_signing_details"; then
  echo "Release DMG is not signed with a Developer ID Application certificate" >&2
  exit 1
fi
if ! grep -q '^Timestamp=' <<< "$dmg_signing_details"; then
  echo "Release DMG does not contain a secure signing timestamp" >&2
  exit 1
fi
dmg_team_id="$(sed -n 's/^TeamIdentifier=//p' <<< "$dmg_signing_details")"
if [[ -z "$dmg_team_id" || "$dmg_team_id" == "not set" ]]; then
  echo "Release DMG does not contain a signing team identifier" >&2
  exit 1
fi
if [[ -n "$expected_team_id" && "$dmg_team_id" != "$expected_team_id" ]]; then
  echo "Expected DMG signing team $expected_team_id, found $dmg_team_id" >&2
  exit 1
fi

notary_arguments=(--keychain-profile "$notary_profile")
if [[ -n "$notary_keychain" ]]; then
  notary_arguments+=(--keychain "$notary_keychain")
fi
notary_result="$release_directory/notarization.plist"
xcrun notarytool submit "$dmg_path" \
  "${notary_arguments[@]}" \
  --wait \
  --timeout 30m \
  --output-format plist > "$notary_result"
notary_status="$(plutil -extract status raw "$notary_result")"
if [[ "$notary_status" != "Accepted" ]]; then
  echo "Apple notarization status was $notary_status, not Accepted" >&2
  exit 1
fi
notary_submission_id="$(plutil -extract id raw "$notary_result")"
notary_log="$release_directory/notarization-log.json"
xcrun notarytool log \
  "$notary_submission_id" \
  "$notary_log" \
  "${notary_arguments[@]}"
python3 - "$notary_log" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as notarization_log:
    issues = json.load(notarization_log).get("issues", [])
if issues:
    print("Apple notarization returned issues:", file=sys.stderr)
    for issue in issues:
        severity = issue.get("severity", "unknown")
        message = issue.get("message", "No message")
        path = issue.get("path", "unknown path")
        print(f"  [{severity}] {path}: {message}", file=sys.stderr)
    raise SystemExit(1)
PYTHON

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
hdiutil verify "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

release_notes_path="$release_directory/Pocus-$version.md"
if [[ -n "$release_notes_file" ]]; then
  cp "$release_notes_file" "$release_notes_path"
else
  printf 'Pocus %s is a signed, notarized universal release for Apple silicon and Intel Macs.\n' \
    "$version" > "$release_notes_path"
fi

sparkle_tools_directory="$project_root/.build/artifacts/sparkle/Sparkle/bin"
"$sparkle_tools_directory/generate_appcast" \
  --ed-key-file "$sparkle_key_file" \
  --download-url-prefix "$download_base_url/" \
  --link "https://github.com/JLSteenwyk/pocus" \
  --embed-release-notes \
  --maximum-deltas 0 \
  "$release_directory"

appcast_path="$release_directory/appcast.xml"
xmllint --noout "$appcast_path"
grep -q "<sparkle:version>$build_number</sparkle:version>" "$appcast_path"
grep -q 'sparkle:edSignature=' "$appcast_path"
grep -Fq "$download_base_url/" "$appcast_path"
shasum -a 256 "$dmg_path" > "$dmg_path.sha256"

printf 'Release is ready at %s\n' "$release_directory"
printf '  version: %s (%s)\n' "$version" "$build_number"
printf '  feed: %s\n' "$feed_url"
