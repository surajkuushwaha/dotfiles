#!/usr/bin/env bash
#
# Delete a testing branch on GitHub and recreate it from the latest
# upstream/development, across every CultureX repo.
#
#   cx recreate        pick a branch, confirm, recreate in all repos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_LIB="${DOTFILES_LIB:-$(cd "$SCRIPT_DIR/../lib" && pwd)}"
# shellcheck source=../lib/colors.sh
source "$DOTFILES_LIB/colors.sh"
# shellcheck source=../lib/repos.sh
source "$DOTFILES_LIB/repos.sh"

ORG="CultureX-art"

BRANCHES=(
  "testing"
  "testing-2"
  "testing-3"
)

divider() {
  echo -e "${OVERLAY2}════════════════════════════════════════${NC}"
}

echo
heading "Select the branch you want to recreate from development:"
echo

PS3="$(echo -e "${LAVENDER}#?${NC} ")"
select BRANCH in "${BRANCHES[@]}" "Cancel"; do
  case "$BRANCH" in
    "testing"|"testing-2"|"testing-3")
      break
      ;;
    "Cancel")
      warn "Cancelled."
      exit 0
      ;;
    *)
      error "Invalid selection. Try again."
      ;;
  esac
done

echo
echo -e "${SUBTEXT0}Selected branch:${NC} ${PEACH}$BRANCH${NC}"
echo

read -r -p "$(echo -e "${YELLOW}?${NC} Recreate ${PEACH}'$BRANCH'${NC} from latest ${GREEN}development${NC} in all repos? ${SUBTEXT0}[y/N]${NC}: ")" CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Cancelled."
  exit 0
fi

for REPO in "${CX_REPOS[@]}"; do
  REPO_PATH="$(resolve_repo_path "$REPO")"

  echo
  divider
  echo -e "${SUBTEXT0}Repo:${NC}   ${MAUVE}$REPO${NC}"
  echo -e "${SUBTEXT0}Branch:${NC} ${PEACH}$BRANCH${NC}"
  divider

  if [ ! -d "$REPO_PATH/.git" ]; then
    error "'$REPO' is not present at ${SUBTEXT0}$REPO_PATH${NC} or is not a git repo. Skipping."
    continue
  fi

  (
    cd "$REPO_PATH"

    log "Fetching latest upstream/development..."
    git fetch upstream development

    log "Latest development commit:"
    echo -e "  ${SUBTEXT1}$(git log -1 --oneline FETCH_HEAD)${NC}"

    log "Deleting remote branch ${PEACH}'$BRANCH'${NC}..."

    if gh api \
      -X DELETE \
      "repos/$ORG/$REPO/git/refs/heads/$BRANCH" \
      >/dev/null 2>&1; then

      success "Deleted ${PEACH}'$BRANCH'${NC}"
    else
      warn "${PEACH}'$BRANCH'${NC} does not exist or could not be deleted."
    fi

    log "Creating ${PEACH}'$BRANCH'${NC} from latest development..."

    git push \
      upstream \
      "FETCH_HEAD:refs/heads/$BRANCH"

    success "${MAUVE}$REPO${NC}/${PEACH}$BRANCH${NC} recreated successfully"
  )
done

echo
divider
success "Finished"
echo -e "${PEACH}'$BRANCH'${NC} now matches latest ${GREEN}development${NC}"
echo -e "${SUBTEXT0}across all available repositories.${NC}"
divider
