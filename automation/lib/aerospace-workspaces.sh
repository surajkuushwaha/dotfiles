#!/usr/bin/env bash
# Shared AeroSpace workspace placement helper.
#
# Source this from a launcher script, then call:
#   aerospace_place_windows "zed|2" "yaak|5"       # place exactly these
#   aerospace_place_windows                        # place the defaults below
#
# Each entry is "app|workspace", where `app` is either an app name
# (as passed to `open -a`, case-insensitive) or a bundle id. Only the apps
# passed in are touched — every other window is left where it is.
#
# AeroSpace's `on-window-detected` rules in aerospace.toml already place
# *newly opened* windows. This helper covers the other case: the app was
# already running, so no new window is detected and no rule fires.
#
# Requires bash 4.4+ (associative arrays, safe empty-array expansion under
# `set -u`). Entry scripts re-exec into one.

# Format: "app|workspace" — used ONLY when aerospace_place_windows is called
# with no arguments.
AEROSPACE_WORKSPACE_MAP=(
  "Zen|1"
  "zed|2"
  "Ghostty|3"
)

# Resolve an app name to its bundle id. Passes bundle ids through unchanged.
aerospace_bundle_id() {
  local app="$1"
  # Already a bundle id (reverse-DNS, no spaces)?
  if [[ "$app" != *" "* && "$app" == *.*.* ]]; then
    echo "$app"
    return 0
  fi
  # Never fail: an unknown app must not abort a caller running `set -e`.
  osascript -e "id of app \"$app\"" 2>/dev/null || true
}

# Seconds to keep re-checking for apps that are still launching.
AEROSPACE_PLACE_TIMEOUT="${AEROSPACE_PLACE_TIMEOUT:-10}"

# Is the app running right now? Used to decide whether a missing window is
# worth waiting for (still launching) or not (never opened).
aerospace_app_is_running() {
  [[ "$(osascript -e "application id \"$1\" is running" 2>/dev/null || true)" == "true" ]]
}

aerospace_place_windows() {
  command -v aerospace >/dev/null 2>&1 || return 0

  # Caller entries only; fall back to the defaults when called bare.
  local -a map=()
  if [[ $# -gt 0 ]]; then
    map=("$@")
  else
    map=("${AEROSPACE_WORKSPACE_MAP[@]}")
  fi
  [[ ${#map[@]} -eq 0 ]] && return 0

  # Resolve bundle ids once — osascript is the slow part. One app can appear
  # twice (two names, same bundle); keep its first position but let the last
  # entry decide the workspace.
  local entry app workspace bundle
  local -A app_of=() workspace_of=()
  local -a order=() targets=()

  for entry in "${map[@]}"; do
    IFS='|' read -r app workspace <<< "$entry"
    [[ -n "$app" && -n "$workspace" ]] || continue

    bundle="$(aerospace_bundle_id "$app")" || bundle=""
    if [[ -z "$bundle" ]]; then
      echo "  ⚠ ${app}: no bundle id, skipped"
      continue
    fi

    [[ -v workspace_of["$bundle"] ]] || order+=("$bundle")
    app_of["$bundle"]="$app"
    workspace_of["$bundle"]="$workspace"
  done

  for bundle in "${order[@]}"; do
    targets+=("${app_of[$bundle]}|$bundle|${workspace_of[$bundle]}")
  done
  [[ ${#targets[@]} -eq 0 ]] && return 0

  local elapsed=0 pending=1
  local windows win_id win_bundle win_workspace found

  # Apps opened moments ago may not have a window yet, so retry until they do.
  while [[ $pending -eq 1 ]]; do
    pending=0
    windows="$(aerospace list-windows --all \
      --format '%{window-id}|%{app-bundle-id}|%{workspace}' 2>/dev/null)" || return 0

    local -a remaining=()
    for entry in "${targets[@]}"; do
      IFS='|' read -r app bundle workspace <<< "$entry"
      found=0

      while IFS='|' read -r win_id win_bundle win_workspace; do
        [[ "$win_bundle" == "$bundle" ]] || continue
        found=1
        [[ "$win_workspace" == "$workspace" ]] && continue
        aerospace move-node-to-workspace --window-id "$win_id" "$workspace" 2>/dev/null
      done <<< "$windows"

      if [[ $found -eq 1 ]]; then
        echo "  ✓ ${app} → workspace ${workspace}"
      elif ! aerospace_app_is_running "$bundle"; then
        : # not running at all — nothing to wait for, stay quiet
      elif [[ $elapsed -lt $AEROSPACE_PLACE_TIMEOUT ]]; then
        remaining+=("$entry")
        pending=1
      else
        echo "  ⚠ ${app}: no window after ${AEROSPACE_PLACE_TIMEOUT}s, skipped"
      fi
    done

    targets=("${remaining[@]}")
    if [[ $pending -eq 1 ]]; then
      sleep 1
      elapsed=$((elapsed + 1))
    fi
  done
}

# Build a map from an APPLICATIONS array whose entries are
# "Display Name|Executable|Workspace" (workspace optional), then place them.
aerospace_place_from_applications() {
  local entry display executable workspace
  local map=()

  for entry in "$@"; do
    IFS='|' read -r display executable workspace <<< "$entry"
    [[ -n "${workspace:-}" ]] || continue
    map+=("$executable|$workspace")
  done

  # No workspace columns at all — do nothing, rather than fall back to defaults.
  [[ ${#map[@]} -eq 0 ]] && return 0

  aerospace_place_windows "${map[@]}"
}
