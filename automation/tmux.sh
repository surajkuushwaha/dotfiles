#!/usr/bin/env bash
# Shared tmux session helpers.
#
# Requires colors.sh to be sourced first (log/success/warn).
#
# Usage:
#   tmux_session_exists "$SESSION"
#   tmux_attach_if_exists "$SESSION"   # execs away when the session exists
#   tmux_attach_session "$SESSION"     # always execs
#   tmux_kill_session "$SESSION"

tmux_session_exists() {
  tmux has-session -t "$1" 2>/dev/null
}

# Attach from outside tmux, switch from inside it (nested attach fails).
tmux_attach_session() {
  local session="$1"

  if [[ -n "${TMUX:-}" ]]; then
    exec tmux switch-client -t "$session"
  else
    exec tmux attach-session -t "$session"
  fi
}

# Attach and never return when the session is already up; otherwise return 0 so
# the caller can go on and build it.
tmux_attach_if_exists() {
  local session="$1"

  if tmux_session_exists "$session"; then
    log "Attaching to existing session: ${MAUVE}${session}${NC}"
    tmux_attach_session "$session"
  fi

  return 0
}

tmux_kill_session() {
  local session="$1"

  if tmux_session_exists "$session"; then
    tmux kill-session -t "$session"
    success "Closed tmux session: ${session}"
  else
    warn "No tmux session named '${session}' found"
  fi
}
