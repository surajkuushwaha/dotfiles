#!/usr/bin/env bash

SESSION="cx-dev"
DEV_MODE=false
TMUX_MODE=false
TEAMS_MODE=false

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
# Set the base path to your repositories
BASE_PATH="/Users/suraj/CultureX/repos"

# Define full paths for each service
SERVER_PATH="$BASE_PATH/cx-saas-server"
ANALYTICS_PATH="$BASE_PATH/cx-analytics-backend"
CREATOR_SERVICE_PATH="$BASE_PATH/cx-creator-services"
DASHBOARD_PATH="$BASE_PATH/cx-saas-dashboard"
SUPER_ADMIN_PATH="$BASE_PATH/saas-super-admin"
WORKER_PATH="$BASE_PATH/cx-worker"
# --- End Configuration ---


# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--dev" ]]; then
    DEV_MODE=true
  fi

  if [[ "$arg" == "--tmux" ]]; then
    TMUX_MODE=true
  fi

  if [[ "$arg" == "--teams" ]]; then
    TEAMS_MODE=true
  fi

  if [[ "$1" == "--close" ]]; then
    if [[ "$*" == *"--dev"* ]]; then
      echo -e "${TEAL}→ Closing VS Code...${NC}"
      osascript -e 'quit app "Visual Studio Code"' 2>/dev/null && echo -e "${GREEN}✓ VS Code closed${NC}" || echo -e "${YELLOW}⚠ VS Code not running${NC}"
    fi
    if [[ "$*" == *"--teams"* ]]; then
      echo -e "${TEAL}→ Closing Microsoft Teams...${NC}"
      osascript -e 'quit app "Microsoft Teams"' 2>/dev/null && echo -e "${GREEN}✓ Microsoft Teams closed${NC}" || echo -e "${YELLOW}⚠ Microsoft Teams not running${NC}"
    fi
    tmux kill-session -t $SESSION 2>/dev/null && echo -e "${GREEN}✓ Session closed${NC}" || echo -e "${YELLOW}⚠ No session to close${NC}"
    exit 0
  fi

  if [[ "$1" == "--list-branches" ]]; then
    echo -e "${LAVENDER}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${LAVENDER}║${NC}  ${MAUVE}Current branches for all repos${NC}           ${LAVENDER}║${NC}"
    echo -e "${LAVENDER}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Server:${NC}          ${GREEN}$(cd "$SERVER_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    echo -e "${BLUE}Analytics:${NC}       ${GREEN}$(cd "$ANALYTICS_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    echo -e "${BLUE}Creator Service:${NC} ${GREEN}$(cd "$CREATOR_SERVICE_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    echo -e "${BLUE}Dashboard:${NC}       ${GREEN}$(cd "$DASHBOARD_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    echo -e "${BLUE}Super Admin:${NC}     ${GREEN}$(cd "$SUPER_ADMIN_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    echo -e "${BLUE}Worker:${NC}          ${GREEN}$(cd "$WORKER_PATH" 2>/dev/null && git branch --show-current 2>/dev/null || echo "${RED}N/A${NC}")${NC}"
    exit 0
  fi
done

# Check if --tmux flag was provided
if ! $TMUX_MODE; then
  echo -e "${RED}Error: --tmux flag is required to start or attach to tmux session${NC}"
  echo ""
  echo -e "${YELLOW}Usage:${NC}"
  echo -e "  ${GREEN}$0 --tmux${NC}                Start/attach to tmux session"
  echo -e "  ${GREEN}$0 --tmux --dev${NC}          Start/attach to tmux session and run dev commands"
  echo -e "  ${GREEN}$0 --tmux --teams${NC}        Start/attach to tmux session and open Microsoft Teams"
  echo -e "  ${GREEN}$0 --tmux --dev --teams${NC}  Start/attach to tmux session, run dev commands, and open Teams"
  echo -e "  ${GREEN}$0 --close${NC}               Close the tmux session"
  echo -e "  ${GREEN}$0 --close --dev${NC}         Close the tmux session and VS Code"
  echo -e "  ${GREEN}$0 --close --teams${NC}       Close the tmux session and Microsoft Teams"
  echo -e "  ${GREEN}$0 --list-branches${NC}       List current branches for all repos"
  exit 1
fi

# If session exists, just attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${TEAL}→ Attaching to existing session: ${MAUVE}$SESSION${NC}"

    # Open Microsoft Teams if requested
    if $TEAMS_MODE; then
      echo -e "${TEAL}→ Opening Microsoft Teams...${NC}"
      open -a "Microsoft Teams" && echo -e "${GREEN}✓ Microsoft Teams opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Microsoft Teams${NC}"
    fi

    exec tmux attach -t "$SESSION"
fi

echo -e "${TEAL}→ Creating new tmux session: ${MAUVE}$SESSION${NC}"


# ---- Window 1: Server ----
# Set the starting directory with -c and let tmux start the default shell
tmux new-session -d -s "$SESSION" -n "Server" -c "$SERVER_PATH"
tmux split-window -h -t "$SESSION:Server" -c "$ANALYTICS_PATH"
# tmux select-layout -t "$SESSION:Server" tiled

# ---- Window 2: Services ----
tmux new-window -t "$SESSION" -n "services" -c "$CREATOR_SERVICE_PATH"
tmux split-window -h -t "$SESSION:services" -c "$WORKER_PATH"

# ---- Window 3: FrontEnd ----
tmux new-window -t "$SESSION" -n "FrontEnd" -c "$DASHBOARD_PATH"
tmux split-window -h -t "$SESSION:FrontEnd" -c "$SUPER_ADMIN_PATH"


# Run dev commands if requested
if $DEV_MODE; then
  # A small sleep helps ensure panes are ready to receive keys
  sleep 0.5
  tmux send-keys -t "$SESSION:Server.0" "code . && ddev" C-m
  tmux send-keys -t "$SESSION:Server.1" "ddev" C-m
  tmux send-keys -t "$SESSION:services.0" "ddev" C-m
#   tmux send-keys -t "$SESSION:services.1" "ddev" C-m
#   tmux send-keys -t "$SESSION:FrontEnd.0" "dev" C-m
#   tmux send-keys -t "$SESSION:FrontEnd.1" "dev" C-m
fi

# Open Microsoft Teams if requested
if $TEAMS_MODE; then
  echo -e "${TEAL}→ Opening Microsoft Teams...${NC}"
  open -a "Microsoft Teams" && echo -e "${GREEN}✓ Microsoft Teams opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Microsoft Teams${NC}"
fi

# Start in Window 1, Pane 1
tmux select-window -t "$SESSION:Server"
tmux select-pane -t ".0"

# Attach to the session
exec tmux attach -t "$SESSION"