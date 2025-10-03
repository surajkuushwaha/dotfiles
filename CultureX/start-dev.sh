#!/usr/bin/env bash

SESSION="cx-dev"
DEV_MODE=false

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

  if [[ "$1" == "--close" ]]; then
    tmux kill-session -t $SESSION 2>/dev/null || echo "no session to close"
    exit 0
  fi
done

# If session exists, just attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Attaching to existing session: $SESSION"
    exec tmux attach -t "$SESSION"
fi


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

# Start in Window 1, Pane 1
tmux select-window -t "$SESSION:Server"
tmux select-pane -t ".0"

# Attach to the session
exec tmux attach -t "$SESSION"