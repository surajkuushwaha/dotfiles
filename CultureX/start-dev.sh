#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="cx-dev"

# --- Colors (Catppuccin Mocha) ---
ROSEWATER='\033[38;2;245;224;220m'
FLAMINGO='\033[38;2;242;205;205m'
PINK='\033[38;2;245;194;231m'
MAUVE='\033[38;2;203;166;247m'
RED='\033[38;2;243;139;168m'
MAROON='\033[38;2;235;160;172m'
PEACH='\033[38;2;250;179;135m'
YELLOW='\033[38;2;249;226;175m'
GREEN='\033[38;2;166;227;161m'
TEAL='\033[38;2;148;226;213m'
SKY='\033[38;2;137;220;235m'
SAPPHIRE='\033[38;2;116;199;236m'
BLUE='\033[38;2;137;180;250m'
LAVENDER='\033[38;2;180;190;254m'
TEXT='\033[38;2;205;214;244m'
SUBTEXT1='\033[38;2;186;194;222m'
SUBTEXT0='\033[38;2;166;173;200m'
OVERLAY2='\033[38;2;147;153;178m'
NC='\033[0m' # No Color

# --- Configuration ---
FEATURE_NAME=""   # mastermind | ntt | empty = use repos only
REPOS_BASE="$HOME/CultureX/repos"
FEATURES_BASE="$HOME/CultureX/features"

# --- Applications Configuration ---
# Format: "Display Name|Executable Name"
# If Display Name and Executable Name are the same, you can just use "App Name|App Name"
APPLICATIONS=(
  # code editors
  # "VS Code|Visual Studio Code"
  # "antigravity|antigravity"
  "cursor|cursor"

  # API Clients
  # "Postman|Postman"
  "Hoppscotch|Hoppscotch"

  # Database Clients
  "MongoDB Compass|MongoDB Compass"
  # "Beekeeper Studio|Beekeeper Studio"
  "Zen Browser|Zen"
  "Microsoft Teams|Microsoft Teams"
)

# --- Functions ---
resolve_repo_path() {
  local repo="$1"
  local feature_path="$FEATURES_BASE/$FEATURE_NAME/$repo"

  if [[ -n "$FEATURE_NAME" && -d "$feature_path" ]]; then
    echo "$feature_path"
  else
    echo "$REPOS_BASE/$repo"
  fi
}

validate_repo_path() {
  local name="$1"
  local path="$2"
  [[ -d "$path" ]] || echo -e "${YELLOW}⚠ ${name} not found at ${path}${NC}"
}

log_repo_paths() {
  local feature_label="${FEATURE_NAME:-none}"
  echo -e "${TEAL}→ Repo paths (feature: ${MAUVE}${feature_label}${TEAL}):${NC}"
  echo -e "  ${SUBTEXT0}cx-saas-server${NC}        → ${SERVER_PATH/#$HOME/\~}"
  validate_repo_path "cx-saas-server" "$SERVER_PATH"
  echo -e "  ${SUBTEXT0}cx-analytics-backend${NC} → ${ANALYTICS_PATH/#$HOME/\~}"
  validate_repo_path "cx-analytics-backend" "$ANALYTICS_PATH"
  echo -e "  ${SUBTEXT0}cx-creator-services${NC}  → ${CREATOR_SERVICE_PATH/#$HOME/\~}"
  validate_repo_path "cx-creator-services" "$CREATOR_SERVICE_PATH"
  echo -e "  ${SUBTEXT0}cx-saas-dashboard${NC}    → ${DASHBOARD_PATH/#$HOME/\~}"
  validate_repo_path "cx-saas-dashboard" "$DASHBOARD_PATH"
  echo -e "  ${SUBTEXT0}saas-super-admin${NC}     → ${SUPER_ADMIN_PATH/#$HOME/\~}"
  validate_repo_path "saas-super-admin" "$SUPER_ADMIN_PATH"
  echo -e "  ${SUBTEXT0}cx-worker${NC}            → ${WORKER_PATH/#$HOME/\~}"
  validate_repo_path "cx-worker" "$WORKER_PATH"
  echo ""
}

close_application() {
  local app_name="$1"
  local app_executable="$2"
  echo -e "${TEAL}→ Closing ${app_name}...${NC}"
  osascript -e "quit app \"$app_executable\"" 2>/dev/null && \
    echo -e "${GREEN}✓ ${app_name} closed${NC}" || \
    echo -e "${YELLOW}⚠ ${app_name} not running${NC}"
}

open_application() {
  local app_name="$1"
  local app_executable="$2"
  echo -e "${TEAL}→ Opening ${app_name}...${NC}"
  open -a "$app_executable" && \
    echo -e "${GREEN}✓ ${app_name} opened${NC}" || \
    echo -e "${YELLOW}⚠ Failed to open ${app_name}${NC}"
}

close_all_applications() {
  for app in "${APPLICATIONS[@]}"; do
    IFS='|' read -r display_name executable <<< "$app"
    close_application "$display_name" "$executable"
  done
}

open_all_applications() {
  for app in "${APPLICATIONS[@]}"; do
    IFS='|' read -r display_name executable <<< "$app"
    open_application "$display_name" "$executable"
  done
}

close_tmux_session() {
  echo -e "${TEAL}→ Closing tmux session...${NC}"
  tmux kill-session -t "$SESSION" 2>/dev/null && \
    echo -e "${GREEN}✓ Tmux session closed${NC}" || \
    echo -e "${YELLOW}⚠ No tmux session to close${NC}"
}

# --- Repo Paths ---
SERVER_PATH="$(resolve_repo_path cx-saas-server)"
ANALYTICS_PATH="$(resolve_repo_path cx-analytics-backend)"
CREATOR_SERVICE_PATH="$(resolve_repo_path cx-creator-services)"
DASHBOARD_PATH="$(resolve_repo_path cx-saas-dashboard)"
SUPER_ADMIN_PATH="$(resolve_repo_path saas-super-admin)"
WORKER_PATH="$(resolve_repo_path cx-worker)"

setup_tmux_session() {
  # If tmux session exists, just attach
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${TEAL}→ Attaching to existing session: ${MAUVE}$SESSION${NC}"
    exec tmux attach -t "$SESSION"
  fi

  echo -e "${TEAL}→ Creating new tmux session: ${MAUVE}$SESSION${NC}"

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
  echo -e "${TEAL}→ Starting dev servers...${NC}"
  sleep 0.5
  tmux send-keys -t "$SESSION:Server.0" "dev" C-m
  # tmux send-keys -t "$SESSION:Server.1" "dev" C-m
  tmux send-keys -t "$SESSION:services.0" "dev" C-m
  tmux send-keys -t "$SESSION:services.1" "dev" C-m
  tmux send-keys -t "$SESSION:FrontEnd.0" "dev" C-m
  tmux send-keys -t "$PR_REVIEWS_TARGET" "bash '$SCRIPT_DIR/start-dev.sh' --pr-review" C-m

  # Start in Window 1, Pane 1
  tmux select-window -t "$SESSION:Server"
  tmux select-pane -t ".0"

  # Attach to the session
  exec tmux attach -t "$SESSION"
}

# --- Main Logic ---
if [[ "$#" -eq 1 && "$1" == "--close" ]]; then
  echo -e "${MAUVE}Closing all applications...${NC}"
  echo ""
  close_all_applications
  echo ""
  close_tmux_session
  exit 0
fi

if [[ "$#" -eq 1 && "$1" == "--tmux" ]]; then
  echo -e "${MAUVE}Starting tmux session...${NC}"
  echo ""
  log_repo_paths
  setup_tmux_session
fi

if [[ "$#" -eq 2 ]] && \
  { [[ "$1" == "--tmux" && "$2" == "--close" ]] || [[ "$1" == "--close" && "$2" == "--tmux" ]]; }; then
  echo -e "${MAUVE}Closing tmux session...${NC}"
  echo ""
  close_tmux_session
  exit 0
fi

if [[ "$#" -eq 1 && "$1" == "--open" ]]; then
  echo -e "${MAUVE}Opening all applications...${NC}"
  echo ""

  # Open all applications
  open_all_applications

  echo ""
  sleep 3  # Give apps time to launch

  log_repo_paths
  setup_tmux_session
fi

if [[ "$#" -eq 1 && "$1" == "--pr-review" ]]; then
  exec "$SCRIPT_DIR/pr-review-requested.sh"
fi

echo -e "${RED}Error: Invalid argument${NC}"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo -e "  ${GREEN}$0 --tmux${NC}          Start or attach to the tmux session only"
echo -e "  ${GREEN}$0 --tmux --close${NC}  Close only the tmux session"
echo -e "  ${GREEN}$0 --open${NC}          Open all applications, start tmux session, and run dev servers"
echo -e "  ${GREEN}$0 --close${NC}         Close all applications and tmux session"
echo -e "  ${GREEN}$0 --pr-review${NC}     List open PRs awaiting your review"
exit 1
