#!/usr/bin/env bash
#
# Delete and recreate CultureX testing branches from a base branch.
#
#   cx testing                      interactive picker
#   cx testing --dry-run            print the git commands, run nothing
#   cx testing -r cx-worker -b testing-2 --yes
#
# Apple ships bash 3.2 at /bin/bash; re-exec under a modern bash for
# associative arrays and namerefs.
if (( BASH_VERSINFO[0] < 4 )); then
  for _bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$_bash" ]] && exec "$_bash" "$0" "$@"
  done
  echo "This script needs bash 4+. Install it with: brew install bash" >&2
  exit 1
fi

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_LIB="${DOTFILES_LIB:-$(cd "$SCRIPT_DIR/../lib" && pwd)}"
# shellcheck source=../lib/colors.sh
source "$DOTFILES_LIB/colors.sh"
# shellcheck source=../lib/repos.sh
source "$DOTFILES_LIB/repos.sh"

# --- Configuration ---
REMOTE="upstream"          # CultureX-art/* — the shared org repo
BASE_BRANCH="development"  # recreated branches start from $REMOTE/$BASE_BRANCH
FEATURE_NAME=""            # mastermind | report-fix | empty = main clones

TESTING_BRANCHES=(testing testing-2 testing-3)

TARGET_REPOS=(
  cx-saas-server
  cx-analytics-backend
  cx-creator-services
  cx-worker
)

# --- Flags ---
ASSUME_YES=0
DRY_RUN=0
FORCE_RESET=0   # push --force base:branch instead of delete + recreate
REPOS_FLAG=""
BRANCHES_FLAG=""

usage() {
  cat <<EOF
$(echo -e "${MAUVE}cx testing${NC}") — delete and recreate testing branches

  -r, --repos    <a,b>   only these repos (default: all four backends)
  -b, --branches <a,b>   only these branches (default: ${TESTING_BRANCHES[*]})
      --remote   <name>  remote to reset on (default: $REMOTE)
      --base     <name>  base branch to recreate from (default: $BASE_BRANCH)
      --feature  <name>  resolve repos inside a feature worktree
      --force-reset      force-push base over the branch instead of deleting it
                         (keeps open PRs alive, one network call)
      --dry-run          print every git command, run none
  -y, --yes              skip the confirmation prompt
  -h, --help             this
EOF
}

while (( $# )); do
  case "$1" in
    -r|--repos)     REPOS_FLAG="${2:-}"; shift 2 ;;
    -b|--branches)  BRANCHES_FLAG="${2:-}"; shift 2 ;;
    --remote)       REMOTE="${2:-}"; shift 2 ;;
    --base)         BASE_BRANCH="${2:-}"; shift 2 ;;
    --feature)      FEATURE_NAME="${2:-}"; shift 2 ;;
    --force-reset)  FORCE_RESET=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -y|--yes)       ASSUME_YES=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Terminal plumbing ────────────────────────────────────────────────

_alt_on=0
alt_screen_on()  { (( _alt_on )) && return; tput smcup 2>/dev/null; tput civis 2>/dev/null; _alt_on=1; }
alt_screen_off() { (( _alt_on )) || return; tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; _alt_on=0; }

RESTORE_REPO=""
RESTORE_HEAD=""

cleanup() {
  alt_screen_off
  # If we died mid-reset with a detached HEAD, put the repo back.
  if [[ -n "$RESTORE_REPO" && -n "$RESTORE_HEAD" ]]; then
    git -C "$RESTORE_REPO" checkout "$RESTORE_HEAD" >/dev/null 2>&1
  fi
}
trap cleanup EXIT INT TERM

# Reads one keypress, echoes a symbolic name.
read_key() {
  local k rest
  IFS= read -rsn1 k || return 1
  case "$k" in
    $'\033')
      read -rsn2 -t 0.05 rest
      case "$rest" in
        '[A') echo up ;;
        '[B') echo down ;;
        '[C') echo right ;;
        '[D') echo left ;;
        *)    echo esc ;;
      esac ;;
    '')  echo enter ;;
    ' ') echo space ;;
    *)   echo "$k" ;;
  esac
}

banner() {
  echo -e "${MAUVE}╭────────────────────────────────────────────────────────────────╮${NC}"
  printf "${MAUVE}│${NC}  %-60s  ${MAUVE}│${NC}\n" "$1"
  echo -e "${MAUVE}╰────────────────────────────────────────────────────────────────╯${NC}"
}

# ── Multi-select menu ────────────────────────────────────────────────
#
# menu_multiselect <title> <subtitle> <labels[]> <hints[]> <enabled[]> <state[]>
# state is read as the initial selection and written back on Enter.
# Returns 0 on Enter, 2 on ← (back), 130 on q/Esc.

menu_render() {
  local title="$1" subtitle="$2" cursor="$3"
  local -n _rl="$4" _rh="$5" _re="$6" _rs="$7"

  printf '\033[H\033[2J'
  banner "$title"
  echo ""
  [[ -n "$subtitle" ]] && { echo -e "  $subtitle"; echo ""; }
  echo -e "  ${SUBTEXT0}↑↓ move · space pick · a all · ⏎ confirm · ← back · q quit${NC}"
  echo ""

  local i label mark row_color prefix
  for i in "${!_rl[@]}"; do
    if [[ "${_re[$i]}" == "1" ]]; then
      if [[ "${_rs[$i]}" == "1" ]]; then mark="${MAUVE}●${NC}"; else mark="${OVERLAY2}○${NC}"; fi
      row_color="$TEXT"
    else
      mark="${RED}✗${NC}"
      row_color="$OVERLAY2"
    fi

    if (( i == cursor )); then prefix="${TEAL}❯${NC} "; else prefix="  "; fi

    label=$(printf '%-22s' "${_rl[$i]}")
    echo -e "  ${prefix}${mark}  ${row_color}${label}${NC} ${SUBTEXT0}${_rh[$i]}${NC}"
  done
  echo ""

  local picked=0
  for i in "${!_rs[@]}"; do [[ "${_rs[$i]}" == "1" ]] && (( picked++ )); done
  echo -e "  ${SUBTEXT0}${picked} selected${NC}"
}

menu_multiselect() {
  local title="$1" subtitle="$2"
  local -n _ml="$3" _mh="$4" _me="$5" _ms="$6"
  local n=${#_ml[@]} cursor=0 key i

  # Park the cursor on the first selectable row.
  while (( cursor < n )) && [[ "${_me[$cursor]}" != "1" ]]; do (( cursor++ )); done
  (( cursor >= n )) && cursor=0

  alt_screen_on
  while true; do
    menu_render "$title" "$subtitle" "$cursor" _ml _mh _me _ms
    key=$(read_key)
    case "$key" in
      up|k)
        for (( i = 1; i <= n; i++ )); do
          local c=$(( (cursor - i + n * i) % n ))
          [[ "${_me[$c]}" == "1" ]] && { cursor=$c; break; }
        done ;;
      down|j)
        for (( i = 1; i <= n; i++ )); do
          local c=$(( (cursor + i) % n ))
          [[ "${_me[$c]}" == "1" ]] && { cursor=$c; break; }
        done ;;
      space)
        if [[ "${_me[$cursor]}" == "1" ]]; then
          [[ "${_ms[$cursor]}" == "1" ]] && _ms[$cursor]=0 || _ms[$cursor]=1
        fi ;;
      a)
        local all=1
        for i in "${!_ms[@]}"; do
          [[ "${_me[$i]}" == "1" && "${_ms[$i]}" != "1" ]] && { all=0; break; }
        done
        for i in "${!_ms[@]}"; do
          [[ "${_me[$i]}" == "1" ]] && { (( all )) && _ms[$i]=0 || _ms[$i]=1; }
        done ;;
      enter)
        local picked=0
        for i in "${!_ms[@]}"; do [[ "${_ms[$i]}" == "1" ]] && (( picked++ )); done
        (( picked > 0 )) && { alt_screen_off; return 0; } ;;
      left|h)  alt_screen_off; return 2 ;;
      q|esc)   alt_screen_off; return 130 ;;
    esac
  done
}

# ── Git helpers ──────────────────────────────────────────────────────

LAST_ERR=""

# Runs git, honours --dry-run, stashes stderr in LAST_ERR.
git_run() {
  if (( DRY_RUN )); then
    echo -e "    ${OVERLAY2}\$ git ${*}${NC}"
    return 0
  fi
  local out rc
  out=$(git "$@" 2>&1); rc=$?
  LAST_ERR=$(echo "$out" | tail -n 1)
  return $rc
}

# Read-only queries always run, even under --dry-run.
git_q() { git "$@" 2>/dev/null; }

has_local_branch()  { git_q -C "$1" show-ref --verify --quiet "refs/heads/$2"; }
has_remote_branch() { [[ -n "$(git_q -C "$1" ls-remote --heads "$REMOTE" "$2")" ]]; }

repo_is_dirty() { [[ -n "$(git_q -C "$1" status --porcelain)" ]]; }

# ── Step output ──────────────────────────────────────────────────────

_step()  { printf "  ${TEAL}→${NC} %-44s" "$1"; }
_ok()    { echo -e "${GREEN}✓${NC} ${SUBTEXT0}${1:-}${NC}"; }
_skip()  { echo -e "${OVERLAY2}─ ${1:-}${NC}"; }
_fail()  { echo -e "${RED}✗${NC} ${RED}${1:-}${NC}"; }

# ── Selection screens ────────────────────────────────────────────────

declare -a SEL_REPOS=()
declare -a SEL_BRANCHES=()

select_repos() {
  local labels=() hints=() enabled=() state=()
  local repo path

  for repo in "${TARGET_REPOS[@]}"; do
    path="$(resolve_repo_path "$repo")"
    labels+=("$repo")
    if [[ -d "$path/.git" ]]; then
      hints+=("${path/#$HOME/\~}")
      enabled+=(1)
      state+=(1)
    else
      hints+=("not a git repo at ${path/#$HOME/\~}")
      enabled+=(0)
      state+=(0)
    fi
  done

  local subtitle="${SUBTEXT0}Remote${NC} ${TEXT}${REMOTE}${NC}   ${SUBTEXT0}Base${NC} ${TEXT}${REMOTE}/${BASE_BRANCH}${NC}"
  [[ -n "$FEATURE_NAME" ]] && subtitle+="   ${SUBTEXT0}Feature${NC} ${MAUVE}${FEATURE_NAME}${NC}"

  menu_multiselect "cx testing · select repos" "$subtitle" labels hints enabled state
  local rc=$?
  (( rc == 0 )) || return $rc

  local i
  SEL_REPOS=()
  for i in "${!labels[@]}"; do
    [[ "${state[$i]}" == "1" ]] && SEL_REPOS+=("${labels[$i]}")
  done
}

# One ls-remote per repo, cached, so the branch screen tells the truth.
declare -A REMOTE_HEADS=()

probe_remote_heads() {
  local repo path
  echo -e "  ${TEAL}→${NC} Reading ${TEXT}${REMOTE}${NC} refs…"
  for repo in "${SEL_REPOS[@]}"; do
    path="$(resolve_repo_path "$repo")"
    REMOTE_HEADS["$repo"]=$(git_q -C "$path" ls-remote --heads "$REMOTE" | awk '{sub("refs/heads/","",$2); print $2}')
  done
}

select_branches() {
  local labels=() hints=() enabled=() state=()
  local branch repo path local_n remote_n total=${#SEL_REPOS[@]}

  for branch in "${TESTING_BRANCHES[@]}"; do
    local_n=0; remote_n=0
    for repo in "${SEL_REPOS[@]}"; do
      path="$(resolve_repo_path "$repo")"
      has_local_branch "$path" "$branch" && (( local_n++ ))
      grep -qxF "$branch" <<<"${REMOTE_HEADS[$repo]:-}" && (( remote_n++ ))
    done

    labels+=("$branch")
    hints+=("local $local_n/$total  ·  $REMOTE $remote_n/$total")
    enabled+=(1)
    state+=(0)
  done

  local subtitle="${SUBTEXT0}Repos${NC} ${TEXT}${SEL_REPOS[*]}${NC}"
  menu_multiselect "cx testing · select branches" "$subtitle" labels hints enabled state
  local rc=$?
  (( rc == 0 )) || return $rc

  local i
  SEL_BRANCHES=()
  for i in "${!labels[@]}"; do
    [[ "${state[$i]}" == "1" ]] && SEL_BRANCHES+=("${labels[$i]}")
  done
}

# ── Plan + confirmation ──────────────────────────────────────────────

show_plan() {
  local repo path branch dirty_any=0 action

  if (( FORCE_RESET )); then
    action="force-push ${REMOTE}/${BASE_BRANCH} over branch"
  else
    action="delete local + ${REMOTE}  →  recreate from ${REMOTE}/${BASE_BRANCH}"
  fi

  echo ""
  echo -e "${RED}╭────────────────────────────────────────────────────────────────╮${NC}"
  printf "${RED}│${NC}  ${YELLOW}⚠  DESTRUCTIVE${NC}  %-45s ${RED}│${NC}\n" "review before continuing"
  echo -e "${RED}╰────────────────────────────────────────────────────────────────╯${NC}"
  echo ""
  echo -e "  ${SUBTEXT0}Plan${NC}   $(( ${#SEL_REPOS[@]} * ${#SEL_BRANCHES[@]} )) branch resets · base ${TEXT}${REMOTE}/${BASE_BRANCH}${NC} · remote ${TEXT}${REMOTE}${NC}"
  (( DRY_RUN )) && echo -e "  ${SUBTEXT0}Mode${NC}   ${GREEN}dry run — nothing will be changed${NC}"
  echo ""

  for repo in "${SEL_REPOS[@]}"; do
    path="$(resolve_repo_path "$repo")"
    echo -e "  ${LAVENDER}${repo}${NC}"
    for branch in "${SEL_BRANCHES[@]}"; do
      printf "    ${TEXT}%-12s${NC} ${SUBTEXT0}%s${NC}\n" "$branch" "$action"
    done
    if repo_is_dirty "$path"; then
      echo -e "    ${YELLOW}⚠ uncommitted changes — this repo will be skipped${NC}"
      dirty_any=1
    fi
  done
  echo ""

  (( dirty_any )) && { warn "Commit or stash the dirty repos to include them."; echo ""; }

  if ! (( FORCE_RESET )) && ! (( DRY_RUN )); then
    echo -e "  ${SUBTEXT0}Deleting a branch on ${REMOTE} closes any open PR that targets it.${NC}"
    echo ""
  fi
}

confirm() {
  (( ASSUME_YES )) && return 0
  (( DRY_RUN )) && return 0
  local answer
  read -r -p "$(echo -e "  Type ${RED}RESET${NC} to proceed: ")" answer
  [[ "$answer" == "RESET" ]]
}

# ── Executor ─────────────────────────────────────────────────────────

OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

reset_branch() {
  local path="$1" branch="$2" head="$3"

  # Never operate on the branch we are standing on.
  if [[ "$head" == "$branch" ]]; then
    _step "$branch  step off current branch"
    if git_run -C "$path" checkout --detach "$REMOTE/$BASE_BRANCH"; then
      _ok "detached"
    else
      _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
    fi
  fi

  if (( FORCE_RESET )); then
    _step "$branch  force-push base over branch"
    if git_run -C "$path" push "$REMOTE" --force "$REMOTE/$BASE_BRANCH:refs/heads/$branch"; then
      _ok
    else
      _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
    fi

    _step "$branch  point local branch at base"
    if git_run -C "$path" branch -f "$branch" "$REMOTE/$BASE_BRANCH"; then
      _ok
    else
      _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
    fi

    git_run -C "$path" fetch "$REMOTE" "$branch"
    git_run -C "$path" branch --set-upstream-to="$REMOTE/$branch" "$branch"
    (( OK_COUNT++ ))
    return 0
  fi

  # 1. local delete
  _step "$branch  delete local"
  if has_local_branch "$path" "$branch"; then
    if git_run -C "$path" branch -D "$branch"; then _ok; else
      _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
    fi
  else
    _skip "absent"
  fi

  # 2. remote delete
  _step "$branch  delete $REMOTE"
  if has_remote_branch "$path" "$branch"; then
    if git_run -C "$path" push "$REMOTE" --delete "$branch"; then _ok; else
      _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
    fi
  else
    _skip "absent"
  fi

  # 3. recreate from base
  _step "$branch  create from $REMOTE/$BASE_BRANCH"
  if git_run -C "$path" branch "$branch" "$REMOTE/$BASE_BRANCH"; then _ok; else
    _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
  fi

  # 4. publish
  _step "$branch  push -u $REMOTE"
  if git_run -C "$path" push -u "$REMOTE" "$branch"; then _ok; else
    _fail "$LAST_ERR"; (( FAIL_COUNT++ )); return 1
  fi

  (( OK_COUNT++ ))
}

reset_repo() {
  local repo="$1"
  local path head branch

  path="$(resolve_repo_path "$repo")"
  echo ""
  echo -e "  ${LAVENDER}${repo}${NC} ${OVERLAY2}$(printf '─%.0s' $(seq 1 $((50 - ${#repo}))))${NC}"

  if [[ ! -d "$path/.git" ]]; then
    _step "locate repo"; _fail "not a git repo at $path"
    (( SKIP_COUNT++ )); return
  fi

  if repo_is_dirty "$path"; then
    _step "worktree clean"; _skip "uncommitted changes — repo skipped"
    (( SKIP_COUNT++ )); return
  fi

  head=$(git_q -C "$path" rev-parse --abbrev-ref HEAD)

  _step "fetch $REMOTE --prune"
  if git_run -C "$path" fetch "$REMOTE" --prune; then _ok; else
    _fail "$LAST_ERR"; (( SKIP_COUNT++ )); return
  fi

  _step "verify $REMOTE/$BASE_BRANCH"
  if git_q -C "$path" rev-parse --verify --quiet "refs/remotes/$REMOTE/$BASE_BRANCH" >/dev/null; then
    _ok
  else
    _fail "base branch missing"; (( SKIP_COUNT++ )); return
  fi

  RESTORE_REPO="$path"
  RESTORE_HEAD="$head"

  for branch in "${SEL_BRANCHES[@]}"; do
    reset_branch "$path" "$branch" "$head"
  done

  # Back to where the repo started.
  if [[ "$(git_q -C "$path" rev-parse --abbrev-ref HEAD)" != "$head" ]]; then
    _step "restore HEAD → $head"
    if git_run -C "$path" checkout "$head"; then _ok; else _fail "$LAST_ERR"; fi
  fi

  RESTORE_REPO=""
  RESTORE_HEAD=""
}

# ── Main ─────────────────────────────────────────────────────────────

main() {
  # Non-interactive selection via flags.
  if [[ -n "$REPOS_FLAG" ]]; then
    IFS=',' read -r -a SEL_REPOS <<<"$REPOS_FLAG"
  fi
  if [[ -n "$BRANCHES_FLAG" ]]; then
    IFS=',' read -r -a SEL_BRANCHES <<<"$BRANCHES_FLAG"
  fi

  if [[ ${#SEL_REPOS[@]} -eq 0 ]]; then
    select_repos
    case $? in
      0) ;;
      130) echo -e "\n${OVERLAY2}Aborted.${NC}"; exit 130 ;;
      *) echo -e "\n${OVERLAY2}Aborted.${NC}"; exit 130 ;;
    esac
  fi

  if [[ ${#SEL_BRANCHES[@]} -eq 0 ]]; then
    probe_remote_heads
    while true; do
      select_branches
      case $? in
        0) break ;;
        2) select_repos || { echo -e "\n${OVERLAY2}Aborted.${NC}"; exit 130; }
           probe_remote_heads ;;
        *) echo -e "\n${OVERLAY2}Aborted.${NC}"; exit 130 ;;
      esac
    done
  fi

  show_plan

  if ! confirm; then
    echo -e "  ${OVERLAY2}Aborted — nothing changed.${NC}"
    exit 1
  fi

  echo ""
  heading "Resetting ${#SEL_BRANCHES[@]} branch(es) across ${#SEL_REPOS[@]} repo(s)…"

  local repo
  for repo in "${SEL_REPOS[@]}"; do
    reset_repo "$repo"
  done

  echo ""
  echo -e "${MAUVE}╭────────────────────────────────────────────────────────────────╮${NC}"
  printf "${MAUVE}│${NC}  ${GREEN}%d ok${NC} · ${RED}%d failed${NC} · ${OVERLAY2}%d repo(s) skipped${NC}%*s${MAUVE}│${NC}\n" \
    "$OK_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" 28 ""
  echo -e "${MAUVE}╰────────────────────────────────────────────────────────────────╯${NC}"

  (( FAIL_COUNT > 0 )) && exit 1
  exit 0
}

main "$@"
