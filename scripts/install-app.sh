#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_app="${1:-$project_root/dist/Pocus.app}"
destination_app="${POCUS_INSTALL_DESTINATION:-/Applications/Pocus.app}"
launch_after_install="${POCUS_LAUNCH_AFTER_INSTALL:-1}"

if [[ ! -d "$source_app" ]]; then
  echo "App bundle not found: $source_app" >&2
  exit 1
fi

source_bundle_id="$(plutil -extract CFBundleIdentifier raw "$source_app/Contents/Info.plist")"
if [[ "$source_bundle_id" != "com.jlsteenwyk.pocus" ]]; then
  echo "Refusing to install an unexpected bundle: $source_bundle_id" >&2
  exit 1
fi

source_path="$(cd "$(dirname "$source_app")" && pwd)/$(basename "$source_app")"
destination_parent="$(dirname "$destination_app")"
mkdir -p "$destination_parent"
destination_parent="$(cd "$destination_parent" && pwd)"
destination_app="$destination_parent/$(basename "$destination_app")"
if [[ "$source_path" == "$destination_app" ]]; then
  echo "Source and destination are the same app bundle" >&2
  exit 1
fi

if [[ -x "$destination_app/Contents/MacOS/Pocus" ]]; then
  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill -TERM "$pid"
  done < <(pgrep -f "^$destination_app/Contents/MacOS/Pocus$" || true)

  for _ in {1..30}; do
    if ! pgrep -f "^$destination_app/Contents/MacOS/Pocus$" >/dev/null; then
      break
    fi
    sleep 0.1
  done
  if pgrep -f "^$destination_app/Contents/MacOS/Pocus$" >/dev/null; then
    echo "Pocus is still running; quit it and try again" >&2
    exit 1
  fi
fi

backup_path=""
if [[ -e "$destination_app" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="$destination_app.backup-$timestamp"
  backup_suffix=1
  while [[ -e "$backup_path" ]]; do
    backup_path="$destination_app.backup-$timestamp-$backup_suffix"
    backup_suffix=$((backup_suffix + 1))
  done
  mv "$destination_app" "$backup_path"
fi

restore_on_failure() {
  status=$?
  trap - EXIT
  if [[ $status -ne 0 ]]; then
    if [[ -e "$destination_app" ]]; then
      failed_path="$destination_app.failed-$(date +%Y%m%d-%H%M%S)"
      mv "$destination_app" "$failed_path"
      echo "Incomplete installation preserved at $failed_path" >&2
    fi
    if [[ -n "$backup_path" ]]; then
      mv "$backup_path" "$destination_app"
      echo "Installation failed; restored $destination_app" >&2
    fi
  fi
  exit "$status"
}
trap restore_on_failure EXIT

ditto "$source_app" "$destination_app"
codesign --verify --deep --strict "$destination_app"
installed_version="$(plutil -extract CFBundleShortVersionString raw "$destination_app/Contents/Info.plist")"
installed_build="$(plutil -extract CFBundleVersion raw "$destination_app/Contents/Info.plist")"

trap - EXIT
printf 'Installed Pocus %s (%s) at %s\n' "$installed_version" "$installed_build" "$destination_app"
if [[ -n "$backup_path" ]]; then
  printf 'Previous installation preserved at %s\n' "$backup_path"
fi

if [[ "$launch_after_install" == "1" ]]; then
  open "$destination_app"
fi
