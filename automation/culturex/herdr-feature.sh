#!/usr/bin/env bash
# Open a CultureX feature as a Herdr space, or jump to it if it is already open.
#
#   herdr-feature.sh <feature|main> [--dev]
#
# <feature> is a folder in ~/CultureX/features. Each repo uses the feature's
# worktree when there is one, else the main clone in ~/CultureX/repos (same rule
# as resolve_repo_path). "main" uses the main clones only.
# --dev starts the dev servers the tmux session starts (server, services, dashboard).
#
# The space is named after the feature (an older cx-<feature> space still counts).
# Prints {"space": "<id>", "created": true|false} on the last line.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_LIB="${DOTFILES_LIB:-$(cd "$SCRIPT_DIR/../lib" && pwd)}"
# shellcheck source=../lib/repos.sh
source "$DOTFILES_LIB/repos.sh"

feature="${1:-}"
dev=0
[[ "${2:-}" == "--dev" ]] && dev=1

if [[ -z "$feature" ]]; then
  echo "Usage: $0 <feature|main> [--dev]" >&2
  exit 1
fi

if [[ "$feature" == "main" ]]; then
  FEATURE_NAME=""
  root="$REPOS_BASE"
else
  FEATURE_NAME="$feature"
  root="$FEATURES_BASE/$feature"
  if [[ ! -d "$root" ]]; then
    echo "No feature folder at $root" >&2
    exit 1
  fi
fi

space_name="$feature"

# Herdr prints JSON for every `herdr-app do`; pull one field out of it.
field() { python3 -I -c "import json,sys; print(json.load(sys.stdin).get('$1', ''))"; }

existing="$(herdr-app ls | python3 -I -c "
import json, sys
for s in json.load(sys.stdin).get('spaces', []):
    if s.get('name') in (sys.argv[1], 'cx-' + sys.argv[1]):
        print(s['id']); break
" "$feature")"

if [[ -n "$existing" ]]; then
  herdr-app do space.select --id "$existing" >/dev/null
  echo "{\"space\": \"$existing\", \"created\": false}"
  exit 0
fi

DEV_ARGV='["zsh","-ic","dev; exec zsh"]'

# argv for a pane: the dev server when --dev and the pane runs one, else a plain shell.
argv_for() {
  if [[ "$dev" == 1 && "$1" == "dev" ]]; then
    printf '%s' "$DEV_ARGV"
  fi
}

# Split the focused pane to the right: <folder> [dev]
split_right() {
  local args=(do terminal.open --folder "$1" --place right)
  local argv; argv="$(argv_for "${2:-}")"
  [[ -n "$argv" ]] && args+=(--argv "$argv")
  herdr-app "${args[@]}" >/dev/null
}

# New tab in the space: <name> <folder> [dev]
new_tab() {
  local args=(do tab.new --space "$space" --name "$1" --folder "$2")
  local argv; argv="$(argv_for "${3:-}")"
  [[ -n "$argv" ]] && args+=(--argv "$argv")
  herdr-app "${args[@]}" | field tab
}

SERVER_PATH="$(resolve_repo_path cx-saas-server)"
WORKER_PATH="$(resolve_repo_path cx-worker)"
CREATOR_SERVICE_PATH="$(resolve_repo_path cx-creator-services)"
ANALYTICS_PATH="$(resolve_repo_path cx-analytics-backend)"
DASHBOARD_PATH="$(resolve_repo_path cx-saas-dashboard)"
SUPER_ADMIN_PATH="$(resolve_repo_path saas-super-admin)"

# ---- Tab 1: Server (server | worker) ----
space_args=(do space.new --name "$space_name" --folder "$SERVER_PATH" --tab Server)
argv="$(argv_for dev)"
[[ -n "$argv" ]] && space_args+=(--argv "$argv")
created="$(herdr-app "${space_args[@]}")"
space="$(field space <<<"$created")"
first_tab="$(field tab <<<"$created")"
split_right "$WORKER_PATH"

# ---- Tab 2: Services (creator-services | analytics) ----
new_tab Services "$CREATOR_SERVICE_PATH" dev >/dev/null
split_right "$ANALYTICS_PATH" dev

# ---- Tab 3: FrontEnd (dashboard | super-admin) ----
new_tab FrontEnd "$DASHBOARD_PATH" dev >/dev/null
split_right "$SUPER_ADMIN_PATH"

# ---- Tab 4: Pending PR Reviews ----
herdr-app do tab.new --space "$space" --name "PR Reviews" --folder "$SCRIPT_DIR" \
  --argv '["zsh","-ic","cx --pr-review; exec zsh"]' >/dev/null

# ---- Tab 5: empty shell at the feature root (where the feature CLAUDE.md lives) ----
herdr-app do tab.new --space "$space" --name Shell --folder "$root" >/dev/null

herdr-app do tab.select --id "$first_tab" >/dev/null
echo "{\"space\": \"$space\", \"created\": true}"
