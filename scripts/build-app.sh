#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${1:-release}"
app_directory="$project_root/dist/Cyclops.app"
contents_directory="$app_directory/Contents"
info_plist="$project_root/Resources/Info.plist"
version="${CYCLOPS_VERSION:-$(plutil -extract CFBundleShortVersionString raw "$info_plist")}"
build_number="${CYCLOPS_BUILD_NUMBER:-$(plutil -extract CFBundleVersion raw "$info_plist")}"
minimum_macos="$(plutil -extract LSMinimumSystemVersion raw "$info_plist")"
architectures="${CYCLOPS_ARCHITECTURES:-$(uname -m)}"
signing_identity="${CYCLOPS_CODE_SIGN_IDENTITY:--}"
feed_url="${CYCLOPS_FEED_URL:-$(plutil -extract SUFeedURL raw "$info_plist")}"
sparkle_framework_source="$project_root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "CYCLOPS_VERSION must be a numeric version such as 0.2.0" >&2
  exit 1
fi

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "CYCLOPS_BUILD_NUMBER must be a positive integer" >&2
  exit 1
fi

if [[ ! "$feed_url" =~ ^https:// ]]; then
  if [[ "${CYCLOPS_ALLOW_INSECURE_LOCAL_FEED:-0}" != "1" || ! "$feed_url" =~ ^http://(127\.0\.0\.1|localhost)(:[0-9]+)?/ ]]; then
    echo "CYCLOPS_FEED_URL must use HTTPS (or an explicitly allowed localhost fixture)" >&2
    exit 1
  fi
fi

read -r -a architecture_list <<< "$architectures"
if [[ ${#architecture_list[@]} -eq 0 ]]; then
  echo "CYCLOPS_ARCHITECTURES must contain arm64, x86_64, or both" >&2
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
    "$(swift build -c "$configuration" --triple "$target_triple" --show-bin-path)/Cyclops"
  )
done

rm -rf "$app_directory"
mkdir -p "$contents_directory/MacOS"
if [[ ${#binary_paths[@]} -eq 1 ]]; then
  cp "${binary_paths[0]}" "$contents_directory/MacOS/Cyclops"
else
  lipo -create "${binary_paths[@]}" -output "$contents_directory/MacOS/Cyclops"
fi
cp "$info_plist" "$contents_directory/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$contents_directory/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$contents_directory/Info.plist"
plutil -replace SUFeedURL -string "$feed_url" "$contents_directory/Info.plist"

if [[ ! -d "$sparkle_framework_source" ]]; then
  echo "Sparkle framework was not resolved at $sparkle_framework_source" >&2
  exit 1
fi
mkdir -p "$contents_directory/Frameworks"
ditto "$sparkle_framework_source" "$contents_directory/Frameworks/Sparkle.framework"

signing_arguments=(
  --force
  --sign "$signing_identity"
)
if [[ "$signing_identity" == "-" ]]; then
  signing_arguments+=(
    --requirements '=designated => identifier "com.jlsteenwyk.pocus"'
  )
else
  signing_arguments+=(--options runtime --timestamp)
fi

sparkle_framework="$contents_directory/Frameworks/Sparkle.framework"
nested_signing_arguments=(
  --force
  --options runtime
  --preserve-metadata=identifier,entitlements
  --sign "$signing_identity"
)
if [[ "$signing_identity" != "-" ]]; then
  nested_signing_arguments+=(--timestamp)
fi
codesign "${nested_signing_arguments[@]}" \
  "$sparkle_framework/Versions/B/Autoupdate"
codesign "${nested_signing_arguments[@]}" \
  "$sparkle_framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${nested_signing_arguments[@]}" \
  "$sparkle_framework/Versions/B/XPCServices/Installer.xpc"
codesign "${nested_signing_arguments[@]}" \
  "$sparkle_framework/Versions/B/Updater.app"
codesign "${nested_signing_arguments[@]}" "$sparkle_framework"
codesign "${signing_arguments[@]}" "$app_directory"

echo "Built $app_directory ($version, build $build_number; ${architecture_list[*]})"
