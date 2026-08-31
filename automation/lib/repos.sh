#!/usr/bin/env bash
# Shared CultureX repo locations + path resolution.
#
# Source this from a script, then use resolve_repo_path/validate_repo_path.
# Set FEATURE_NAME *after* sourcing to point the resolver at a feature
# worktree instead of the main clone.

REPOS_BASE="${REPOS_BASE:-$HOME/CultureX/repos}"
FEATURES_BASE="${FEATURES_BASE:-$HOME/CultureX/features}"
FEATURE_NAME="${FEATURE_NAME:-}"

# Every repo we work with, in display order.
CX_REPOS=(
  cx-saas-server
  cx-analytics-backend
  cx-creator-services
  cx-saas-dashboard
  saas-super-admin
  cx-worker
)

# Feature worktree wins when it exists, otherwise the main clone.
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
  [[ -d "$path" ]] || warn "${name} not found at ${path}"
}
