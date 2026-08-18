#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${1:-release}"
app_directory="$project_root/dist/Pocus.app"
contents_directory="$app_directory/Contents"
info_plist="$project_root/Resources/Info.plist"
version="${POCUS_VERSION:-$(plutil -extract CFBundleShortVersionString raw "$info_plist")}"
build_number="${POCUS_BUILD_NUMBER:-$(plutil -extract CFBundleVersion raw "$info_plist")}"
minimum_macos="$(plutil -extract LSMinimumSystemVersion raw "$info_plist")"
architectures="${POCUS_ARCHITECTURES:-$(uname -m)}"
signing_identity="${POCUS_CODE_SIGN_IDENTITY:--}"

if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "POCUS_VERSION must be a numeric version such as 0.2.0" >&2
  exit 1
fi

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "POCUS_BUILD_NUMBER must be a positive integer" >&2
  exit 1
fi

read -r -a architecture_list <<< "$architectures"
if [[ ${#architecture_list[@]} -eq 0 ]]; then
  echo "POCUS_ARCHITECTURES must contain arm64, x86_64, or both" >&2
  exit 1
fi

cd "$project_root"
binary_paths=()
for architecture in "${architecture_list[@]}"; do
  case "$architecture" in
    arm64 | x86_64) ;;
    *)
      echo "Unsupported architecture: $architecture" >&2
      exit 1
      ;;
  esac

  target_triple="$architecture-apple-macosx$minimum_macos"
  swift build -c "$configuration" --triple "$target_triple"
  binary_paths+=(
    "$(swift build -c "$configuration" --triple "$target_triple" --show-bin-path)/Pocus"
  )
done

rm -rf "$app_directory"
mkdir -p "$contents_directory/MacOS"
if [[ ${#binary_paths[@]} -eq 1 ]]; then
  cp "${binary_paths[0]}" "$contents_directory/MacOS/Pocus"
else
  lipo -create "${binary_paths[@]}" -output "$contents_directory/MacOS/Pocus"
fi
cp "$info_plist" "$contents_directory/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$contents_directory/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$contents_directory/Info.plist"

signing_arguments=(
  --force
  --options runtime
  --sign "$signing_identity"
)
if [[ "$signing_identity" == "-" ]]; then
  signing_arguments+=(
    --requirements '=designated => identifier "com.jlsteenwyk.pocus"'
  )
else
  signing_arguments+=(--timestamp)
fi
codesign "${signing_arguments[@]}" "$app_directory"

echo "Built $app_directory ($version, build $build_number; ${architecture_list[*]})"
