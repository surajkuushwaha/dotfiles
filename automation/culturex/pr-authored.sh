#!/usr/bin/env bash

# --- Colors (Catppuccin Mocha) ---
MAUVE='\033[38;2;203;166;247m'
YELLOW='\033[38;2;249;226;175m'
GREEN='\033[38;2;166;227;161m'
RED='\033[38;2;243;139;168m'
TEAL='\033[38;2;148;226;213m'
SUBTEXT0='\033[38;2;166;173;200m'
SUBTEXT1='\033[38;2;186;194;222m'
TEXT='\033[38;2;205;214;244m'
NC='\033[0m'

# --- Configuration (matches start-dev.sh) ---
: "${FEATURE_NAME:=}"   # inherited from start-dev.sh when run via cx --pr
REPOS_BASE="$HOME/CultureX/repos"
FEATURES_BASE="$HOME/CultureX/features"
TARGET_REMOTE="upstream"
PR_SEARCH_AUTHORED="sort:updated-desc is:pr is:open author:@me"
PR_JSON_FIELDS="number,title,url,updatedAt,baseRefName,mergeable,mergeStateStatus"

REPOS=(
  cx-saas-server
  cx-analytics-backend
  cx-creator-services
  cx-saas-dashboard
  saas-super-admin
  cx-worker
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

get_repo_slug() {
  local path="$1"
  local url

  url=$(git -C "$path" config --get "remote.${TARGET_REMOTE}.url" 2>/dev/null)
  if [[ -z "$url" ]]; then
    url=$(git -C "$path" config --get remote.origin.url 2>/dev/null)
  fi
  [[ -n "$url" ]] || return 1

  echo "$url" | sed -E 's/.*:([^/]+\/[^/]+)\.git$/\1/'
}

format_updated_at() {
  local iso="$1"
  date -j -f "%Y-%m-%dT%H:%M:%SZ" "${iso%%.*}Z" "+%d %b %Y" 2>/dev/null || echo "${iso%%T*}"
}

truncate() {
  local text="$1"
  local max="$2"
  if ((${#text} > max)); then
    echo "${text:0:max-1}…"
  else
    echo "$text"
  fi
}

merge_label() {
  local mergeable="$1"
  local status="$2"

  if [[ "$mergeable" == "CONFLICTING" || "$status" == "DIRTY" ]]; then
    echo "conflict"
    return
  fi
  case "$status" in
    CLEAN)     echo "ok" ;;
    BEHIND)    echo "behind" ;;
    BLOCKED)   echo "blocked" ;;
    UNSTABLE)  echo "unstable" ;;
    UNKNOWN)   echo "…" ;;
    *)         echo "$status" ;;
  esac
}

merge_color() {
  case "$1" in
    conflict) echo "$RED" ;;
    ok)       echo "$GREEN" ;;
    behind|blocked|unstable) echo "$YELLOW" ;;
    *)        echo "$SUBTEXT0" ;;
  esac
}

fetch_repo_prs() {
  local slug="$1"
  local prs

  prs="$(gh pr list -R "$slug" \
    --search "$PR_SEARCH_AUTHORED" \
    --json "$PR_JSON_FIELDS" \
    --limit 100 2>/dev/null)" || return 1
  [[ -n "$prs" ]] || return 1

  echo "$prs"
}

print_repo_table() {
  local repo="$1"
  local prs_json="$2"
  local repo_count short_repo sep

  repo_count="$(jq 'length' <<< "$prs_json")"
  short_repo="${repo#*/}"
  sep="$(printf '─%.0s' {1..96})"

  echo -e "${MAUVE}${sep}${NC}"
  echo -e "${MAUVE} ${short_repo}${NC} ${SUBTEXT0}(${repo_count} PR(s))${NC}"
  echo -e "${MAUVE}${sep}${NC}"
  printf "  ${SUBTEXT0}%-7s %-40s %-14s %-12s %-10s %s${NC}\n" \
    "PR #" "Title" "Base" "Updated" "Merge" "Link"
  printf "  ${SUBTEXT0}%-7s %-40s %-14s %-12s %-10s %s${NC}\n" \
    "──────" "────────────────────────────────────────" \
    "──────────────" "────────────" "──────────" \
    "────────────────────────────"

  while IFS=$'\t' read -r number title base updated mergeable merge_status url; do
    updated_fmt="$(format_updated_at "$updated")"
    title_fmt="$(truncate "$title" 40)"
    base_fmt="$(truncate "$base" 14)"
    merge_fmt="$(merge_label "$mergeable" "$merge_status")"
    merge_c="$(merge_color "$merge_fmt")"
    printf "  ${TEXT}#%-6s${NC} ${TEXT}%-40s${NC} ${SUBTEXT1}%-14s${NC} ${SUBTEXT0}%-12s${NC} ${merge_c}%-10s${NC} ${TEAL}%s${NC}\n" \
      "$number" "$title_fmt" "$base_fmt" "$updated_fmt" "$merge_fmt" "$url"
  done < <(jq -r 'sort_by(.updatedAt) | reverse | .[] |
    "\(.number)\t\(.title)\t\(.baseRefName)\t\(.updatedAt)\t\(.mergeable)\t\(.mergeStateStatus)\t\(.url)"' <<< "$prs_json")

  echo ""
}

# --- Main ---
if ! command -v gh >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ gh CLI not found${NC}"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠ jq not found${NC}"
  exit 1
fi

feature_label="${FEATURE_NAME:-none}"
echo -e "${TEAL}→ PRs raised by you (feature: ${MAUVE}${feature_label}${TEAL})${NC}"
echo ""

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Parallel: one worker per repo
for repo in "${REPOS[@]}"; do
  (
    path="$(resolve_repo_path "$repo")"

    if [[ ! -d "$path" ]]; then
      printf 'skip\t%s\n' "Skipping ${repo}: not found at ${path/#$HOME/\~}" >"$work/$repo.meta"
      exit 0
    fi

    slug="$(get_repo_slug "$path")" || {
      printf 'skip\t%s\n' "Skipping ${repo}: no git remote found" >"$work/$repo.meta"
      exit 0
    }

    if ! prs="$(fetch_repo_prs "$slug")"; then
      printf 'skip\t%s\n' "Failed to fetch PRs for ${slug}" >"$work/$repo.meta"
      exit 0
    fi

    jq --arg repo "$slug" 'map(. + {repo: $repo})' <<<"$prs" >"$work/$repo.json"
    printf 'ok\n' >"$work/$repo.meta"
  ) &
done
wait

all_prs="[]"
skipped=0

for repo in "${REPOS[@]}"; do
  meta="$work/$repo.meta"
  if [[ ! -f "$meta" ]]; then
    echo -e "${YELLOW}⚠ Skipping ${repo}: worker produced no result${NC}"
    ((skipped++)) || true
    continue
  fi

  status="$(head -n1 "$meta" | cut -f1)"
  if [[ "$status" != "ok" ]]; then
    msg="$(cut -f2- "$meta")"
    echo -e "${YELLOW}⚠ ${msg}${NC}"
    ((skipped++)) || true
    continue
  fi

  all_prs="$(jq --slurpfile incoming "$work/$repo.json" '. + $incoming[0]' <<< "$all_prs")"
done

count="$(jq 'length' <<< "$all_prs")"

if [[ "$count" -eq 0 ]]; then
  echo -e "${GREEN}✓ No open PRs raised by you${NC}"
  [[ "$skipped" -gt 0 ]] && echo -e "${SUBTEXT0}  (${skipped} repo(s) skipped)${NC}"
  exit 0
fi

while IFS= read -r group; do
  repo="$(jq -r '.repo' <<< "$group")"
  prs_json="$(jq -c '.prs' <<< "$group")"
  print_repo_table "$repo" "$prs_json"
done < <(jq -c '
  group_by(.repo)
  | map({
      repo: .[0].repo,
      prs: sort_by(.updatedAt) | reverse,
      latest: (max_by(.updatedAt).updatedAt)
    })
  | sort_by(.latest) | reverse
  | .[]
' <<< "$all_prs")

echo -e "${GREEN}✓ ${count} open PR(s) raised by you${NC}"
[[ "$skipped" -gt 0 ]] && echo -e "${SUBTEXT0}  (${skipped} repo(s) skipped)${NC}"
exit 0
