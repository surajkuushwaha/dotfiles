#!/usr/bin/env bash

set -euo pipefail

SESSION="dev"
PROJECTS_DIR="$HOME/Personal/projects"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers. Override DOTFILES_LIB to source them from elsewhere.
DOTFILES_LIB="${DOTFILES_LIB:-$(cd "$SCRIPT_DIR/../lib" && pwd)}"
# shellcheck source=../lib/colors.sh
source "$DOTFILES_LIB/colors.sh"
# shellcheck source=../lib/applications.sh
source "$DOTFILES_LIB/applications.sh"
# shellcheck source=../lib/tmux.sh
source "$DOTFILES_LIB/tmux.sh"
# shellcheck source=../lib/aerospace-workspaces.sh
source "$DOTFILES_LIB/aerospace-workspaces.sh"

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
  # "dsa|dsa|"
  "profile-scope|profile-scope|"
)

# -----------------------------------------------------------------------------
# Tmux
# -----------------------------------------------------------------------------
setup_tmux() {

  # Session already exists — attach and never come back.
  tmux_attach_if_exists "$SESSION"

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

  tmux_attach_session "$SESSION"
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
  tmux_kill_session "$SESSION"
  exit 0
fi

# sk --close
if $CLOSE; then
  apps_close_all "${APPLICATIONS[@]}"
  tmux_kill_session "$SESSION"
  exit 0
fi

# sk --open
if $OPEN; then
  apps_open_all "${APPLICATIONS[@]}"
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
