#!/usr/bin/env bash
#
# Reset a testing branch on GitHub to the latest upstream/development,
# across every CultureX repo.
#
#   cx recreate        pick a branch, confirm, recreate in all repos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_LIB="${DOTFILES_LIB:-$(cd "$SCRIPT_DIR/../lib" && pwd)}"
# shellcheck source=../lib/colors.sh
source "$DOTFILES_LIB/colors.sh"
# shellcheck source=../lib/repos.sh
source "$DOTFILES_LIB/repos.sh"

BRANCHES=(
  "testing"
  "testing-1"
  "testing-2"
  "testing-3"
)

divider() {
  echo -e "${OVERLAY2}════════════════════════════════════════${NC}"
}

BRANCH="$(printf '%s\n' "${BRANCHES[@]}" \
  | fzf --prompt='Recreate branch> ' --height=40% --reverse \
        --header='Branch to reset to latest development')"

if [[ -z "$BRANCH" ]]; then
  warn "Cancelled."
  exit 0
fi

echo
echo -e "${SUBTEXT0}Selected branch:${NC} ${PEACH}$BRANCH${NC}"
echo

read -r -p "$(echo -e "${YELLOW}?${NC} Recreate ${PEACH}'$BRANCH'${NC} from latest ${GREEN}development${NC} in all repos? ${SUBTEXT0}[y/N]${NC}: ")" CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Cancelled."
  exit 0
fi

SUCCEEDED=()
FAILED=()
SKIPPED=()

# Fetch development and force-push it onto the branch. A single force push
# is atomic: the branch is never missing, and PRs targeting it stay open.
recreate_in_repo() {
  log "Fetching latest upstream/development..."
  git fetch upstream development || return 1

  log "Latest development commit:"
  echo -e "  ${SUBTEXT1}$(git log -1 --oneline FETCH_HEAD)${NC}"

  log "Resetting ${PEACH}'$BRANCH'${NC} to latest development..."
  git push --force upstream "FETCH_HEAD:refs/heads/$BRANCH"
}

for REPO in "${CX_REPOS[@]}"; do
  REPO_PATH="$(resolve_repo_path "$REPO")"

  echo
  divider
  echo -e "${SUBTEXT0}Repo:${NC}   ${MAUVE}$REPO${NC}"
  echo -e "${SUBTEXT0}Branch:${NC} ${PEACH}$BRANCH${NC}"
  divider

  if [ ! -d "$REPO_PATH/.git" ]; then
    error "'$REPO' is not present at ${SUBTEXT0}$REPO_PATH${NC} or is not a git repo. Skipping."
    SKIPPED+=("$REPO")
    continue
  fi

  if (cd "$REPO_PATH" && recreate_in_repo); then
    success "${MAUVE}$REPO${NC}/${PEACH}$BRANCH${NC} recreated successfully"
    SUCCEEDED+=("$REPO")
  else
    error "${MAUVE}$REPO${NC}/${PEACH}$BRANCH${NC} failed. Continuing with the rest."
    FAILED+=("$REPO")
  fi
done

echo
divider
heading "Summary for ${PEACH}'$BRANCH'${MAUVE}:"
for r in "${SUCCEEDED[@]}"; do success "$r"; done
for r in "${SKIPPED[@]}";   do warn "$r ${SUBTEXT0}(not found, skipped)${NC}"; done
for r in "${FAILED[@]}";    do error "$r"; done
divider

[[ ${#FAILED[@]} -eq 0 ]]
