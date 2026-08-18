#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_app="${1:-$project_root/dist/Cyclops.app}"
destination_app="${CYCLOPS_INSTALL_DESTINATION:-/Applications/Cyclops.app}"
launch_after_install="${CYCLOPS_LAUNCH_AFTER_INSTALL:-1}"
legacy_app=""
if [[ -z "${CYCLOPS_INSTALL_DESTINATION+x}" && -e "/Applications/Pocus.app" ]]; then
  legacy_app="/Applications/Pocus.app"
fi

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

stop_running_app() {
  local app_path="$1"
  local executable_name="$2"
  local product_name="$3"
  local executable_path="$app_path/Contents/MacOS/$executable_name"

  [[ -x "$executable_path" ]] || return 0

  while IFS= read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill -TERM "$pid"
  done < <(pgrep -f "^$executable_path$" || true)

  for _ in {1..30}; do
    if ! pgrep -f "^$executable_path$" >/dev/null; then
      break
    fi
    sleep 0.1
  done
  if pgrep -f "^$executable_path$" >/dev/null; then
    echo "$product_name is still running; quit it and try again" >&2
    exit 1
  fi
}

stop_running_app "$destination_app" "Cyclops" "Cyclops"
if [[ -n "$legacy_app" ]]; then
  stop_running_app "$legacy_app" "Pocus" "Pocus"
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

legacy_backup_path=""
if [[ -n "$legacy_app" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  legacy_backup_path="$legacy_app.backup-$timestamp"
  backup_suffix=1
  while [[ -e "$legacy_backup_path" ]]; do
    legacy_backup_path="$legacy_app.backup-$timestamp-$backup_suffix"
    backup_suffix=$((backup_suffix + 1))
  done
  mv "$legacy_app" "$legacy_backup_path"
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
    if [[ -n "$legacy_backup_path" ]]; then
      mv "$legacy_backup_path" "$legacy_app"
      echo "Installation failed; restored $legacy_app" >&2
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
printf 'Installed Cyclops %s (%s) at %s\n' "$installed_version" "$installed_build" "$destination_app"
if [[ -n "$backup_path" ]]; then
  printf 'Previous installation preserved at %s\n' "$backup_path"
fi
if [[ -n "$legacy_backup_path" ]]; then
  printf 'Previous Pocus installation preserved at %s\n' "$legacy_backup_path"
fi

if [[ "$launch_after_install" == "1" ]]; then
  open "$destination_app"
fi
