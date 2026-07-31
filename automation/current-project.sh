#!/usr/bin/env bash

set -euo pipefail

SESSION="dev"
PROJECTS_DIR="$HOME/Personal/projects"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./aerospace-workspaces.sh
source "$SCRIPT_DIR/aerospace-workspaces.sh"

# -----------------------------------------------------------------------------
# Applications
# Format: "Display Name|Executable Name|AeroSpace Workspace"
# Workspace is optional — leave it off to let the app land wherever.
# -----------------------------------------------------------------------------
APPLICATIONS=(
  # "Cursor|Cursor|4"
  "Zen Browser|Zen|1"
  "zed|zed|2"
)

# -----------------------------------------------------------------------------
# Projects
# Format:
# "Window Name|Directory Relative to PROJECTS_DIR|Command"
# Leave command empty if nothing should be started.
# -----------------------------------------------------------------------------
PROJECTS=(
  # "social-lens|social-lens|"
  "dsa|dsa|"
)

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  echo -e "${BLUE}→${NC} $1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# -----------------------------------------------------------------------------
# Applications
# -----------------------------------------------------------------------------
open_all_applications() {
  for app in "${APPLICATIONS[@]}"; do
    IFS='|' read -r display executable _workspace <<< "$app"

    log "Opening ${display}..."
    open -a "$executable" >/dev/null 2>&1 || warn "Failed to open ${display}"
  done
}

close_all_applications() {
  for app in "${APPLICATIONS[@]}"; do
    IFS='|' read -r display executable _workspace <<< "$app"

    log "Closing ${display}..."
    osascript -e "quit app \"$executable\"" >/dev/null 2>&1 || true
  done
}

# -----------------------------------------------------------------------------
# Tmux
# -----------------------------------------------------------------------------
close_tmux() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION"
    success "Closed tmux session: $SESSION"
  else
    warn "No tmux session named '$SESSION' found."
  fi
}

setup_tmux() {

  # Session already exists
  if tmux has-session -t "$SESSION" 2>/dev/null; then

    if [[ -n "${TMUX:-}" ]]; then
      log "Switching to existing session..."
      exec tmux switch-client -t "$SESSION"
    else
      log "Attaching to existing session..."
      exec tmux attach-session -t "$SESSION"
    fi

  fi

  log "Creating tmux session..."

  local first=true

  for project in "${PROJECTS[@]}"; do

    IFS='|' read -r window directory command <<< "$project"

    path="$PROJECTS_DIR/$directory"

    if [[ ! -d "$path" ]]; then
      warn "$path not found."
      continue
    fi

    if $first; then
      tmux new-session \
        -d \
        -s "$SESSION" \
        -n "$window" \
        -c "$path"

      first=false
    else
      tmux new-window \
        -t "$SESSION" \
        -n "$window" \
        -c "$path"
    fi

    if [[ -n "$command" ]]; then
      tmux send-keys \
        -t "$SESSION:$window" \
        "$command" \
        C-m
    fi

  done

  tmux select-window -t "$SESSION:1"

  if [[ -n "${TMUX:-}" ]]; then
    exec tmux switch-client -t "$SESSION"
  else
    exec tmux attach-session -t "$SESSION"
  fi
}

usage() {
cat <<EOF

Usage:
  $(basename "$0") --tmux
      Create or attach to the tmux session.

  $(basename "$0") --open
      Open applications and start tmux.

  $(basename "$0") --close
      Close applications and kill tmux session.

  $(basename "$0") --tmux --close
      Kill only the tmux session.

EOF
}

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
OPEN=false
CLOSE=false
TMUX_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --open)
      OPEN=true
      ;;
    --close)
      CLOSE=true
      ;;
    --tmux)
      TMUX_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      usage
      exit 1
      ;;
  esac
done

# -----------------------------------------------------------------------------
# Execute
# -----------------------------------------------------------------------------

# sk --tmux --close
if $TMUX_ONLY && $CLOSE; then
  close_tmux
  exit 0
fi

# sk --close
if $CLOSE; then
  close_all_applications
  close_tmux
  exit 0
fi

# sk --open
if $OPEN; then
  open_all_applications
  sleep 2
  log "Placing windows on AeroSpace workspaces..."
  aerospace_place_from_applications "${APPLICATIONS[@]}"
  setup_tmux
  exit 0
fi

# sk --tmux
if $TMUX_ONLY; then
  setup_tmux
  exit 0
fi

usage
exit 1
