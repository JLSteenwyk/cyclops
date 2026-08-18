#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port="${POCUS_UPDATE_FIXTURE_PORT:-8765}"
base_version="${POCUS_FIXTURE_BASE_VERSION:-0.3.0}"
base_build="${POCUS_FIXTURE_BASE_BUILD:-4}"
update_version="${POCUS_FIXTURE_UPDATE_VERSION:-0.3.1}"
update_build="${POCUS_FIXTURE_UPDATE_BUILD:-5}"
feed_url="http://127.0.0.1:$port/appcast.xml"
sparkle_tools_directory="$project_root/.build/artifacts/sparkle/Sparkle/bin"

mkdir -p "$project_root/dist"
fixture_directory="${POCUS_UPDATE_FIXTURE_DIRECTORY:-$(mktemp -d "$project_root/dist/update-fixture.XXXXXX")}"
installed_directory="$fixture_directory/installed"
server_directory="$fixture_directory/server"
mkdir -p "$installed_directory" "$server_directory"
printf '%s\n' "$fixture_directory" > "$project_root/dist/latest-update-fixture-path"

build_fixture_app() {
  local version="$1"
  local build_number="$2"
  env \
    POCUS_VERSION="$version" \
    POCUS_BUILD_NUMBER="$build_number" \
    POCUS_ARCHITECTURES="arm64 x86_64" \
    POCUS_FEED_URL="$feed_url" \
    POCUS_ALLOW_INSECURE_LOCAL_FEED=1 \
    "$project_root/scripts/build-app.sh"
}

build_fixture_app "$base_version" "$base_build"
ditto "$project_root/dist/Pocus.app" "$installed_directory/Pocus.app"

build_fixture_app "$update_version" "$update_build"
env \
  POCUS_EXPECTED_VERSION="$update_version" \
  POCUS_EXPECTED_BUILD_NUMBER="$update_build" \
  POCUS_EXPECTED_ARCHITECTURES="arm64 x86_64" \
  "$project_root/scripts/verify-app.sh" "$project_root/dist/Pocus.app"

archive_path="$server_directory/Pocus-$update_version.zip"
ditto -c -k --sequesterRsrc --keepParent \
  "$project_root/dist/Pocus.app" \
  "$archive_path"
printf '%s\n' \
  "Pocus $update_version adds secure automatic updates and keeps the focus workflow uninterrupted." \
  > "$server_directory/Pocus-$update_version.md"

key_file="${POCUS_SPARKLE_PRIVATE_KEY_FILE:-}"
temporary_key_directory=""
if [[ -z "$key_file" ]]; then
  temporary_key_directory="$(mktemp -d /tmp/pocus-sparkle-key.XXXXXX)"
  key_file="$temporary_key_directory/private-key"
  "$sparkle_tools_directory/generate_keys" \
    --account com.jlsteenwyk.pocus \
    -x "$key_file"
  chmod 600 "$key_file"
fi

cleanup_key() {
  if [[ -n "$temporary_key_directory" ]]; then
    unlink "$key_file"
    rmdir "$temporary_key_directory"
  fi
}
trap cleanup_key EXIT

"$sparkle_tools_directory/generate_appcast" \
  --ed-key-file "$key_file" \
  --download-url-prefix "http://127.0.0.1:$port/" \
  --link "https://github.com/JLSteenwyk/pocus" \
  --embed-release-notes \
  --maximum-deltas 0 \
  "$server_directory"

appcast_path="$server_directory/appcast.xml"
grep -q "<sparkle:version>$update_build</sparkle:version>" "$appcast_path"
grep -q "sparkle:edSignature=" "$appcast_path"
grep -q "sparkle-signatures:" "$appcast_path"

printf 'Created signed update fixture at %s\n' "$fixture_directory"
printf '  installed: %s (%s)\n' "$base_version" "$base_build"
printf '  available: %s (%s)\n' "$update_version" "$update_build"
printf '  serve: python3 -m http.server %s --bind 127.0.0.1 --directory %s\n' \
  "$port" \
  "$server_directory"
