#!/usr/bin/env bash
# Shared macOS application open/close helpers.
#
# Requires colors.sh to be sourced first (log/success/warn).
#
# Entries use the same format as the AeroSpace helper:
#   "Display Name|Executable Name|Workspace"   (workspace optional, ignored here)
#
# Usage:
#   apps_open_all "${APPLICATIONS[@]}"
#   apps_close_all "${APPLICATIONS[@]}"

app_open() {
  local display="$1"
  local executable="$2"

  log "Opening ${display}..."
  if open -a "$executable" >/dev/null 2>&1; then
    success "${display} opened"
  else
    warn "Failed to open ${display}"
  fi
}

app_close() {
  local display="$1"
  local executable="$2"

  log "Closing ${display}..."
  if osascript -e "quit app \"$executable\"" >/dev/null 2>&1; then
    success "${display} closed"
  else
    warn "${display} not running"
  fi
}

apps_open_all() {
  local entry display executable _workspace

  for entry in "$@"; do
    IFS='|' read -r display executable _workspace <<< "$entry"
    [[ -n "$display" && -n "$executable" ]] || continue
    app_open "$display" "$executable"
  done
}

apps_close_all() {
  local entry display executable _workspace

  for entry in "$@"; do
    IFS='|' read -r display executable _workspace <<< "$entry"
    [[ -n "$display" && -n "$executable" ]] || continue
    app_close "$display" "$executable"
  done
}
