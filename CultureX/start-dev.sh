#!/usr/bin/env bash

SESSION="cx-dev"
VSCODE_MODE=false
START_MODE=false
TMUX_MODE=false
TEAMS_MODE=false
POSTMAN_MODE=false
MONGO_MODE=false
ZEN_MODE=false

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
  if [[ "$arg" == "--vscode" ]]; then
    VSCODE_MODE=true
  fi

  if [[ "$arg" == "--start" ]]; then
    START_MODE=true
  fi

  if [[ "$arg" == "--tmux" ]]; then
    TMUX_MODE=true
  fi

  if [[ "$arg" == "--teams" ]]; then
    TEAMS_MODE=true
  fi

  if [[ "$arg" == "--postman" ]]; then
    POSTMAN_MODE=true
  fi

  if [[ "$arg" == "--mongo" ]]; then
    MONGO_MODE=true
  fi

  if [[ "$arg" == "--zen" ]]; then
    ZEN_MODE=true
  fi

  if [[ "$arg" == "--all" ]]; then
    VSCODE_MODE=true
    TEAMS_MODE=true
    POSTMAN_MODE=true
    MONGO_MODE=true
    ZEN_MODE=true
    START_MODE=true
  fi

  if [[ "$1" == "--close" ]]; then
    if [[ "$*" == *"--all"* ]]; then
      echo -e "${TEAL}→ Closing VS Code...${NC}"
      osascript -e 'quit app "Visual Studio Code"' 2>/dev/null && echo -e "${GREEN}✓ VS Code closed${NC}" || echo -e "${YELLOW}⚠ VS Code not running${NC}"
      echo -e "${TEAL}→ Closing Microsoft Teams...${NC}"
      osascript -e 'quit app "Microsoft Teams"' 2>/dev/null && echo -e "${GREEN}✓ Microsoft Teams closed${NC}" || echo -e "${YELLOW}⚠ Microsoft Teams not running${NC}"
      echo -e "${TEAL}→ Closing Postman...${NC}"
      osascript -e 'quit app "Postman"' 2>/dev/null && echo -e "${GREEN}✓ Postman closed${NC}" || echo -e "${YELLOW}⚠ Postman not running${NC}"
      echo -e "${TEAL}→ Closing MongoDB Compass...${NC}"
      osascript -e 'quit app "MongoDB Compass"' 2>/dev/null && echo -e "${GREEN}✓ MongoDB Compass closed${NC}" || echo -e "${YELLOW}⚠ MongoDB Compass not running${NC}"
      echo -e "${TEAL}→ Closing Zen Browser...${NC}"
      osascript -e 'quit app "Zen Browser"' 2>/dev/null && echo -e "${GREEN}✓ Zen Browser closed${NC}" || echo -e "${YELLOW}⚠ Zen Browser not running${NC}"
    else
      if [[ "$*" == *"--vscode"* ]]; then
        echo -e "${TEAL}→ Closing VS Code...${NC}"
        osascript -e 'quit app "Visual Studio Code"' 2>/dev/null && echo -e "${GREEN}✓ VS Code closed${NC}" || echo -e "${YELLOW}⚠ VS Code not running${NC}"
      fi
      if [[ "$*" == *"--teams"* ]]; then
        echo -e "${TEAL}→ Closing Microsoft Teams...${NC}"
        osascript -e 'quit app "Microsoft Teams"' 2>/dev/null && echo -e "${GREEN}✓ Microsoft Teams closed${NC}" || echo -e "${YELLOW}⚠ Microsoft Teams not running${NC}"
      fi
      if [[ "$*" == *"--postman"* ]]; then
        echo -e "${TEAL}→ Closing Postman...${NC}"
        osascript -e 'quit app "Postman"' 2>/dev/null && echo -e "${GREEN}✓ Postman closed${NC}" || echo -e "${YELLOW}⚠ Postman not running${NC}"
      fi
      if [[ "$*" == *"--mongo"* ]]; then
        echo -e "${TEAL}→ Closing MongoDB Compass...${NC}"
        osascript -e 'quit app "MongoDB Compass"' 2>/dev/null && echo -e "${GREEN}✓ MongoDB Compass closed${NC}" || echo -e "${YELLOW}⚠ MongoDB Compass not running${NC}"
      fi
      if [[ "$*" == *"--zen"* ]]; then
        echo -e "${TEAL}→ Closing Zen Browser...${NC}"
        osascript -e 'quit app "Zen"' 2>/dev/null && echo -e "${GREEN}✓ Zen Browser closed${NC}" || echo -e "${YELLOW}⚠ Zen Browser not running${NC}"
      fi
    fi
    tmux kill-session -t $SESSION 2>/dev/null && echo -e "${GREEN}✓ Session closed${NC}" || echo -e "${YELLOW}⚠ No session to close${NC}"
    exit 0
  fi

  if [[ "$1" == "--list-branches" ]]; then
    echo -e "${LAVENDER}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${LAVENDER}║${NC}  ${MAUVE}Repository Status Overview${NC}               ${LAVENDER}║${NC}"
    echo -e "${LAVENDER}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # Function to display repo status
    show_repo_status() {
      local repo_name="$1"
      local repo_path="$2"

      if [[ ! -d "$repo_path" ]]; then
        echo -e "${BLUE}${repo_name}:${NC} ${RED}Directory not found${NC}"
        echo ""
        return
      fi

      cd "$repo_path" 2>/dev/null || return

      local branch=$(git branch --show-current 2>/dev/null || echo "N/A")
      echo -e "${BLUE}${repo_name}:${NC} ${GREEN}${branch}${NC}"

      # Get git status
      local status_output=$(git status --porcelain 2>/dev/null)

      if [[ -z "$status_output" ]]; then
        echo -e "  ${GREEN}✓ Clean working directory${NC}"
      else
        # Count and display staged files
        local staged=$(echo "$status_output" | grep -E '^[MADRC]' | wc -l | tr -d ' ')
        # Count and display unstaged files
        local unstaged=$(echo "$status_output" | grep -E '^.[MD]' | wc -l | tr -d ' ')
        # Count and display untracked files
        local untracked=$(echo "$status_output" | grep -E '^\?\?' | wc -l | tr -d ' ')

        if [[ $staged -gt 0 ]]; then
          echo -e "  ${GREEN}Staged:${NC} ${YELLOW}${staged} file(s)${NC}"
          echo "$status_output" | grep -E '^[MADRC]' | while read -r line; do
            local file=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | cut -c1)
            case $status in
              M) echo -e "    ${GREEN}M${NC} ${file}" ;;
              A) echo -e "    ${GREEN}A${NC} ${file}" ;;
              D) echo -e "    ${RED}D${NC} ${file}" ;;
              R) echo -e "    ${BLUE}R${NC} ${file}" ;;
              C) echo -e "    ${BLUE}C${NC} ${file}" ;;
            esac
          done
        fi

        if [[ $unstaged -gt 0 ]]; then
          echo -e "  ${RED}Unstaged:${NC} ${YELLOW}${unstaged} file(s)${NC}"
          echo "$status_output" | grep -E '^.[MD]' | while read -r line; do
            local file=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | cut -c2)
            case $status in
              M) echo -e "    ${RED}M${NC} ${file}" ;;
              D) echo -e "    ${RED}D${NC} ${file}" ;;
            esac
          done
        fi

        if [[ $untracked -gt 0 ]]; then
          echo -e "  ${SUBTEXT0}Untracked:${NC} ${YELLOW}${untracked} file(s)${NC}"
          echo "$status_output" | grep -E '^\?\?' | while read -r line; do
            local file=$(echo "$line" | awk '{print $2}')
            echo -e "    ${SUBTEXT0}?${NC} ${file}"
          done
        fi
      fi
      echo ""
    }

    show_repo_status "Server         " "$SERVER_PATH"
    show_repo_status "Analytics      " "$ANALYTICS_PATH"
    show_repo_status "Creator Service" "$CREATOR_SERVICE_PATH"
    show_repo_status "Dashboard      " "$DASHBOARD_PATH"
    show_repo_status "Super Admin    " "$SUPER_ADMIN_PATH"
    show_repo_status "Worker         " "$WORKER_PATH"

    exit 0
  fi
done

# Check if no arguments were provided
if [ $# -eq 0 ]; then
  echo -e "${RED}Error: No arguments provided${NC}"
  echo ""
  echo -e "${YELLOW}Usage:${NC}"
  echo -e "  ${GREEN}$0 --tmux${NC}                      Start/attach to tmux session"
  echo -e "  ${GREEN}$0 --tmux --start${NC}              Start/attach and run dev servers (server, analytics, creator service)"
  echo -e "  ${GREEN}$0 --tmux --vscode${NC}             Start/attach to tmux session and open VS Code"
  echo -e "  ${GREEN}$0 --tmux --teams${NC}              Start/attach to tmux session and open Microsoft Teams"
  echo -e "  ${GREEN}$0 --tmux --postman${NC}            Start/attach to tmux session and open Postman"
  echo -e "  ${GREEN}$0 --tmux --mongo${NC}              Start/attach to tmux session and open MongoDB Compass"
  echo -e "  ${GREEN}$0 --tmux --zen${NC}                Start/attach to tmux session and open Zen Browser"
  echo -e "  ${GREEN}$0 --tmux --all${NC}                Start/attach to tmux session and open all apps (VS Code, Teams, Postman, MongoDB, Zen)"
  echo -e "  ${GREEN}$0 --tmux --start --vscode${NC}     Start dev servers and open VS Code"
  echo -e "  ${GREEN}$0 --close${NC}                     Close the tmux session"
  echo -e "  ${GREEN}$0 --close --all${NC}               Close the tmux session and all apps"
  echo -e "  ${GREEN}$0 --close --vscode${NC}            Close the tmux session and VS Code"
  echo -e "  ${GREEN}$0 --close --teams${NC}             Close the tmux session and Microsoft Teams"
  echo -e "  ${GREEN}$0 --close --postman${NC}           Close the tmux session and Postman"
  echo -e "  ${GREEN}$0 --close --mongo${NC}             Close the tmux session and MongoDB Compass"
  echo -e "  ${GREEN}$0 --close --zen${NC}               Close the tmux session and Zen Browser"
  echo -e "  ${GREEN}$0 --list-branches${NC}             List current branches for all repos"
  exit 1
fi

  # Open MongoDB Compass if requested
if $MONGO_MODE; then
  echo -e "${TEAL}→ Opening MongoDB Compass...${NC}"
  open -a "MongoDB Compass" && echo -e "${GREEN}✓ MongoDB opened${NC}" || echo -e "${YELLOW}⚠ Failed to open MongoDB${NC}"
fi

# Open Zen Browser if requested
if $ZEN_MODE; then
  echo -e "${TEAL}→ Opening Zen Browser...${NC}"
  open -a "Zen" && echo -e "${GREEN}✓ Zen Browser opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Zen Browser${NC}"
fi

# Open Microsoft Teams if requested
if $TEAMS_MODE; then
  echo -e "${TEAL}→ Opening Microsoft Teams...${NC}"
  open -a "Microsoft Teams" && echo -e "${GREEN}✓ Microsoft Teams opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Microsoft Teams${NC}"
fi

# Open Postman if requested
if $POSTMAN_MODE; then
  echo -e "${TEAL}→ Opening Postman...${NC}"
  open -a "Postman" && echo -e "${GREEN}✓ Postman opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Postman${NC}"
fi

sleep 3  # Give the app time to launch before attaching

# If session exists, just attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${TEAL}→ Attaching to existing session: ${MAUVE}$SESSION${NC}"

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
if $START_MODE; then
  # A small sleep helps ensure panes are ready to receive keys
  sleep 0.5
  tmux send-keys -t "$SESSION:Server.0" "ddev" C-m
  tmux send-keys -t "$SESSION:Server.1" "ddev" C-m
  tmux send-keys -t "$SESSION:services.0" "ddev" C-m
fi

# Open VS Code if requested
if $VSCODE_MODE; then
  echo -e "${TEAL}→ Opening VS Code in server directory...${NC}"
  code "$SERVER_PATH" && echo -e "${GREEN}✓ VS Code opened${NC}" || echo -e "${YELLOW}⚠ Failed to open VS Code${NC}"
fi

# Open Microsoft Teams if requested
if $TEAMS_MODE; then
  echo -e "${TEAL}→ Opening Microsoft Teams...${NC}"
  open -a "Microsoft Teams" && echo -e "${GREEN}✓ Microsoft Teams opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Microsoft Teams${NC}"
fi

# Open Postman if requested
if $POSTMAN_MODE; then
  echo -e "${TEAL}→ Opening Postman...${NC}"
  open -a "Postman" && echo -e "${GREEN}✓ Postman opened${NC}" || echo -e "${YELLOW}⚠ Failed to open Postman${NC}"
fi

# Open MongoDB Compass if requested
if $MONGO_MODE; then
  echo -e "${TEAL}→ Opening MongoDB Compass...${NC}"
  if open -a "MongoDB Compass" 2>&1; then
    sleep 3  # Give the app time to launch
    echo -e "${GREEN}✓ MongoDB Compass opened${NC}"
  else
    echo -e "${YELLOW}⚠ Failed to open MongoDB Compass${NC}"
  fi
fi

# Open Zen Browser if requested
if $ZEN_MODE; then
  echo -e "${TEAL}→ Opening Zen Browser...${NC}"
  if open -a "Zen" 2>&1; then
    sleep 3  # Give the app time to launch
    echo -e "${GREEN}✓ Zen Browser opened${NC}"
  else
    echo -e "${YELLOW}⚠ Failed to open Zen Browser${NC}"
  fi
fi

# Start in Window 1, Pane 1
tmux select-window -t "$SESSION:Server"
tmux select-pane -t ".0"

# Attach to the session
exec tmux attach -t "$SESSION"