#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${1:-release}"
app_directory="$project_root/dist/Pocus.app"
contents_directory="$app_directory/Contents"

cd "$project_root"
swift build -c "$configuration"
binary_path="$(swift build -c "$configuration" --show-bin-path)/Pocus"

rm -rf "$app_directory"
mkdir -p "$contents_directory/MacOS"
cp "$binary_path" "$contents_directory/MacOS/Pocus"
cp "$project_root/Resources/Info.plist" "$contents_directory/Info.plist"

codesign --force --sign - "$app_directory"

echo "Built $app_directory"
