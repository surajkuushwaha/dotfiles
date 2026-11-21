#!/usr/bin/env bash

# Apple ships bash 3.2 (2007) at /bin/bash and it usually wins the PATH, so
# re-exec under a modern bash when one is installed. Needed for associative
# arrays and safe empty-array expansion under `set -u`.
if (( BASH_VERSINFO[0] < 4 )); then
  for _bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_bash" ]] && exec "$_bash" "$0" "$@"
  done
  echo "This script needs bash 4+. Install it with: brew install bash" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="cx-dev"   # one session, whichever feature it was started with

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
# shellcheck source=../lib/repos.sh
source "$DOTFILES_LIB/repos.sh"

# --- Applications Configuration ---
# Format: "Display Name|Executable Name|AeroSpace Workspace"
# If Display Name and Executable Name are the same, you can just use "App Name|App Name|N"
# Workspace is optional — leave it off to let the app land wherever.
APPLICATIONS=(
  # browsers
  "Zen Browser|Zen|1"

  # code editors
  "VS Code|Visual Studio Code|2"
  # "antigravity|antigravity|2"
  # "cursor|cursor|2"
  "orca|orca|6"

  # terminal / agents
  "Herdr|Herdr|3"

  # API Clients
  "Postman|Postman|4"
  # "Hoppscotch|Hoppscotch|5"
  # "yaak|yaak|4"

  # Database Clients
  # "MongoDB Compass|MongoDB Compass|5"
  # "Beekeeper Studio|Beekeeper Studio|5"
   "DBX|DBX|5"

  # Communication
  "Microsoft Teams|Microsoft Teams|0"
)

# --- Functions ---
log_repo_paths() {
  local feature_label="${FEATURE_NAME:-none}"
  log "Repo paths (feature: ${MAUVE}${feature_label}${TEAL}):${NC}"
  echo -e "  ${SUBTEXT0}cx-saas-server${NC}        → ${SERVER_PATH/#$HOME/~}"
  validate_repo_path "cx-saas-server" "$SERVER_PATH"
  echo -e "  ${SUBTEXT0}cx-analytics-backend${NC} → ${ANALYTICS_PATH/#$HOME/~}"
  validate_repo_path "cx-analytics-backend" "$ANALYTICS_PATH"
  echo -e "  ${SUBTEXT0}cx-creator-services${NC}  → ${CREATOR_SERVICE_PATH/#$HOME/~}"
  validate_repo_path "cx-creator-services" "$CREATOR_SERVICE_PATH"
  echo -e "  ${SUBTEXT0}cx-saas-dashboard${NC}    → ${DASHBOARD_PATH/#$HOME/~}"
  validate_repo_path "cx-saas-dashboard" "$DASHBOARD_PATH"
  echo -e "  ${SUBTEXT0}saas-super-admin${NC}     → ${SUPER_ADMIN_PATH/#$HOME/~}"
  validate_repo_path "saas-super-admin" "$SUPER_ADMIN_PATH"
  echo -e "  ${SUBTEXT0}cx-worker${NC}            → ${WORKER_PATH/#$HOME/~}"
  validate_repo_path "cx-worker" "$WORKER_PATH"
  echo ""
}

# Point repo paths at a feature folder in $FEATURES_BASE,
# or at the main clones in $REPOS_BASE when no feature is given.
use_feature() {
  FEATURE_NAME="${1:-}"
  if [[ -n "$FEATURE_NAME" && ! -d "$FEATURES_BASE/$FEATURE_NAME" ]]; then
    error "No feature folder at ${FEATURES_BASE/#$HOME/~}/$FEATURE_NAME"
    exit 1
  fi
  SERVER_PATH="$(resolve_repo_path cx-saas-server)"
  ANALYTICS_PATH="$(resolve_repo_path cx-analytics-backend)"
  CREATOR_SERVICE_PATH="$(resolve_repo_path cx-creator-services)"
  DASHBOARD_PATH="$(resolve_repo_path cx-saas-dashboard)"
  SUPER_ADMIN_PATH="$(resolve_repo_path saas-super-admin)"
  WORKER_PATH="$(resolve_repo_path cx-worker)"
}

# Ask which feature to use: "repos" (main clones) or a folder in $FEATURES_BASE.
# Prints the feature name, or nothing for repos. Exits when cancelled.
pick_feature() {
  local choices=(repos) dir choice
  for dir in "$FEATURES_BASE"/*/; do
    [[ -d "$dir" ]] && choices+=("$(basename "$dir")")
  done

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "${choices[@]}" | fzf --height=~40% --reverse --prompt="feature> ")" || exit 0
  else
    PS3="Select a feature: "
    select choice in "${choices[@]}"; do
      [[ -n "$choice" ]] && break
    done
    [[ -n "$choice" ]] || exit 0
  fi

  [[ "$choice" == "repos" ]] || echo "$choice"
}

setup_tmux_session() {
  # Session already exists — attach and never come back.
  tmux_attach_if_exists "$SESSION"

  log "Creating new tmux session: ${MAUVE}${SESSION}${NC}"

  # ---- Window 1: Server ----
  tmux new-session -d -s "$SESSION" -n "Server" -c "$SERVER_PATH"
  tmux split-window -h -t "$SESSION:Server" -c "$WORKER_PATH"

  # ---- Window 2: Services ----
  tmux new-window -t "$SESSION" -n "services" -c "$CREATOR_SERVICE_PATH"
  tmux split-window -h -t "$SESSION:services" -c "$ANALYTICS_PATH"

  # ---- Window 3: FrontEnd ----
  tmux new-window -t "$SESSION" -n "FrontEnd" -c "$DASHBOARD_PATH"
  tmux split-window -h -t "$SESSION:FrontEnd" -c "$SUPER_ADMIN_PATH"

  # ---- Window 4: Pending PR Reviews ----
  tmux new-window -t "$SESSION" -n "Pending PR Reviews" -c "$SCRIPT_DIR"
  PR_REVIEWS_TARGET="$(tmux display-message -p -t "$SESSION" '#{session_name}:#{window_index}')"

  # Start dev servers
  log "Starting dev servers..."
  sleep 0.5
  tmux send-keys -t "$SESSION:Server.0" "dev" C-m
  # tmux send-keys -t "$SESSION:Server.1" "dev" C-m
  tmux send-keys -t "$SESSION:services.0" "dev" C-m
  tmux send-keys -t "$SESSION:services.1" "dev" C-m
  tmux send-keys -t "$SESSION:FrontEnd.0" "dev" C-m
  tmux send-keys -t "$PR_REVIEWS_TARGET" "cx --pr-review" C-m

  # Start in Window 1, Pane 1
  tmux select-window -t "$SESSION:Server"
  tmux select-pane -t ".0"

  # Attach to the session
  tmux_attach_session "$SESSION"
}

usage() {
  echo -e "${YELLOW}Usage:${NC}"
  echo -e "  ${GREEN}$0 --tmux [feature]${NC}   Start or attach to the tmux session only (no feature: pick one)"
  echo -e "  ${GREEN}$0 --tmux --close${NC}     Close only the tmux session"
  echo -e "  ${GREEN}$0 --open [feature]${NC}   Open all applications, start tmux session, and run dev servers"
  echo -e "  ${GREEN}$0 --close${NC}            Close all applications and the tmux session"
  echo -e "  ${GREEN}$0 --pr-review${NC}        List open PRs awaiting your review"
  echo -e "  ${GREEN}$0 --pr${NC}               List open PRs raised by you"
  echo ""
  echo -e "  ${SUBTEXT0}[feature] is a folder in ${FEATURES_BASE/#$HOME/~}; each repo uses its worktree there"
  echo -e "  when present, else ${REPOS_BASE/#$HOME/~}. Only one cx-dev session runs at a time.${NC}"
}

invalid() {
  error "$1"
  echo ""
  usage
  exit 1
}

# --- Main Logic ---
# Parse every argument first, then run one action.
mode="" close=0 feature=""
for arg in "$@"; do
  case "$arg" in
    --tmux | --open | --pr-review | --pr)
      [[ -z "$mode" ]] || invalid "Use only one of --tmux, --open, --pr-review, --pr"
      mode="${arg#--}"
      ;;
    --close) close=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) invalid "Unknown option: $arg" ;;
    *)
      [[ -z "$feature" ]] || invalid "Only one feature allowed"
      feature="$arg"
      ;;
  esac
done

# A feature only means something when starting the tmux session.
if [[ -n "$feature" ]] && { [[ "$mode" != tmux && "$mode" != open ]] || (( close )); }; then
  invalid "A feature only goes with --tmux or --open"
fi

case "$mode:$close" in
  ":1")
    heading "Closing all applications..."
    echo ""
    apps_close_all "${APPLICATIONS[@]}"
    echo ""
    tmux_kill_session "$SESSION"
    ;;

  "tmux:1")
    heading "Closing tmux session..."
    echo ""
    tmux_kill_session "$SESSION"
    ;;

  "tmux:0")
    # Already running: attach to it, whatever feature it was started with.
    tmux_attach_if_exists "$SESSION"
    # No feature given: ask, unless there is no terminal to ask on (then repos).
    [[ -z "$feature" && -t 0 ]] && feature="$(pick_feature)"
    use_feature "$feature"
    heading "Starting tmux session..."
    echo ""
    log_repo_paths
    setup_tmux_session
    ;;

  "open:0")
    use_feature "$feature"
    heading "Opening all applications..."
    echo ""
    apps_open_all "${APPLICATIONS[@]}"
    echo ""
    sleep 3  # Give apps time to launch

    log "Placing windows on AeroSpace workspaces..."
    aerospace_place_from_applications "${APPLICATIONS[@]}"
    echo ""

    log_repo_paths
    setup_tmux_session
    ;;

  "pr-review:0") exec "$SCRIPT_DIR/pr-review-requested.sh" ;;
  "pr:0")        exec "$SCRIPT_DIR/pr-authored.sh" ;;
  ":0")          invalid "No option given" ;;
  *)             invalid "--close only goes alone or with --tmux" ;;
esac
exit 0
