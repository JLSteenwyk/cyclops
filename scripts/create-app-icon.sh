#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_image="${1:-$project_root/Resources/CyclopsAppIcon.png}"
output_path="${2:-$project_root/dist/Cyclops.icns}"

if [[ ! -f "$source_image" ]]; then
  echo "App icon source not found: $source_image" >&2
  exit 1
fi

source_width="$(sips -g pixelWidth "$source_image" | awk '/pixelWidth:/ {print $2}')"
source_height="$(sips -g pixelHeight "$source_image" | awk '/pixelHeight:/ {print $2}')"
if [[ "$source_width" != "1024" || "$source_height" != "1024" ]]; then
  echo "App icon source must be 1024x1024 pixels" >&2
  exit 1
fi

temporary_directory="$(mktemp -d /tmp/cyclops-icon.XXXXXX)"
iconset="$temporary_directory/Cyclops.iconset"
cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

mkdir -p "$iconset" "$(dirname "$output_path")"

render_icon() {
  local pixels="$1"
  local filename="$2"
  sips -z "$pixels" "$pixels" "$source_image" --out "$iconset/$filename" >/dev/null
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

iconutil --convert icns "$iconset" --output "$output_path"
printf 'Created %s\n' "$output_path"
