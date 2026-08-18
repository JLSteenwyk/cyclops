#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_directory="${1:-$project_root/dist/Cyclops.app}"
version="${CYCLOPS_VERSION:-$(plutil -extract CFBundleShortVersionString raw "$app_directory/Contents/Info.plist")}"
output_path="${2:-$project_root/dist/Cyclops-$version.dmg}"
volume_name="Cyclops $version"

if [[ ! -d "$app_directory" ]]; then
  echo "App bundle not found: $app_directory" >&2
  exit 1
fi

staging_directory="$(mktemp -d /tmp/cyclops-dmg.XXXXXX)"
cleanup() {
  rm -rf "$staging_directory"
}
trap cleanup EXIT

ditto "$app_directory" "$staging_directory/Cyclops.app"
ln -s /Applications "$staging_directory/Applications"
mkdir -p "$(dirname "$output_path")"

hdiutil create \
  -volname "$volume_name" \
  -fs APFS \
  -format ULFO \
  -srcfolder "$staging_directory" \
  -ov \
  "$output_path"
hdiutil verify "$output_path"

printf 'Created %s\n' "$output_path"
