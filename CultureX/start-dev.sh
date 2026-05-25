#!/usr/bin/env bash

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
BASE_PATH="$HOME/CultureX/features/mastermind"
BASE_PATH2="$HOME/CultureX/repos"
SERVER_PATH="$BASE_PATH/cx-saas-server"
ANALYTICS_PATH="$BASE_PATH/cx-analytics-backend"
CREATOR_SERVICE_PATH="$BASE_PATH/cx-creator-services"
DASHBOARD_PATH="$BASE_PATH2/cx-saas-dashboard"
SUPER_ADMIN_PATH="$BASE_PATH2/saas-super-admin"
WORKER_PATH="$BASE_PATH2/cx-worker"

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

  # Start dev servers
  echo -e "${TEAL}→ Starting dev servers...${NC}"
  sleep 0.5
  tmux send-keys -t "$SESSION:Server.0" "dev" C-m
  # tmux send-keys -t "$SESSION:Server.1" "dev" C-m
  tmux send-keys -t "$SESSION:services.0" "dev" C-m
  tmux send-keys -t "$SESSION:services.1" "dev" C-m
  tmux send-keys -t "$SESSION:FrontEnd.0" "dev" C-m

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

  # Setup and attach to tmux session
  setup_tmux_session
fi

echo -e "${RED}Error: Invalid argument${NC}"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo -e "  ${GREEN}$0 --tmux${NC}          Start or attach to the tmux session only"
echo -e "  ${GREEN}$0 --tmux --close${NC}  Close only the tmux session"
echo -e "  ${GREEN}$0 --open${NC}          Open all applications, start tmux session, and run dev servers"
echo -e "  ${GREEN}$0 --close${NC}         Close all applications and tmux session"
exit 1
