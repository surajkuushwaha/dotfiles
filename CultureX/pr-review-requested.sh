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
: "${FEATURE_NAME:=}"   # inherited from start-dev.sh when run via cx --pr-review
REPOS_BASE="$HOME/CultureX/repos"
FEATURES_BASE="$HOME/CultureX/features"
TARGET_REMOTE="upstream"
PR_SEARCH_PENDING="sort:updated-desc is:pr is:open user-review-requested:@me"
PR_SEARCH_REVIEWED="sort:updated-desc is:pr is:open reviewed-by:@me"
PR_JSON_FIELDS="number,title,url,updatedAt,author,mergeable,mergeStateStatus"

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

review_color() {
  case "$1" in
    pending)            echo "$YELLOW" ;;
    changes-requested)  echo "$RED" ;;
    approved)           echo "$GREEN" ;;
    commented)          echo "$TEAL" ;;
    *)                  echo "$SUBTEXT0" ;;
  esac
}

# Latest review state for $GH_USER on a PR → pending|changes-requested|approved|commented|…
my_latest_review_status() {
  local slug="$1"
  local number="$2"
  local reviews state

  reviews="$(gh api "repos/${slug}/pulls/${number}/reviews" --paginate 2>/dev/null)" || {
    echo "…"
    return
  }

  state="$(jq -r --arg user "$GH_USER" '
    [.[] | select(.user.login == $user and .state != "PENDING")]
    | sort_by(.submitted_at)
    | last
    | .state // empty
  ' <<< "$reviews")"

  case "$state" in
    CHANGES_REQUESTED) echo "changes-requested" ;;
    APPROVED)          echo "approved" ;;
    COMMENTED|DISMISSED|"") echo "commented" ;;
    *)                 echo "commented" ;;
  esac
}

# Union pending + reviewed searches; tag pending (A or A∩B) vs enrich B-only
fetch_repo_prs() {
  local slug="$1"
  local tmp pending_file reviewed_file enrich_dir
  local pending reviewed merged numbers number status_map pe re

  tmp="$(mktemp -d)"
  pending_file="$tmp/pending.json"
  reviewed_file="$tmp/reviewed.json"
  enrich_dir="$tmp/enrich"
  mkdir -p "$enrich_dir"

  # Parallel: both searches for this repo
  gh pr list -R "$slug" \
    --search "$PR_SEARCH_PENDING" \
    --json "$PR_JSON_FIELDS" \
    --limit 100 >"$pending_file" 2>/dev/null &
  pe=$!
  gh pr list -R "$slug" \
    --search "$PR_SEARCH_REVIEWED" \
    --json "$PR_JSON_FIELDS" \
    --limit 100 >"$reviewed_file" 2>/dev/null &
  re=$!
  wait "$pe"; pe=$?
  wait "$re"; re=$?
  if [[ "$pe" -ne 0 || "$re" -ne 0 ]]; then
    rm -rf "$tmp"
    return 1
  fi

  pending="$(<"$pending_file")"
  reviewed="$(<"$reviewed_file")"
  [[ -n "$pending" && -n "$reviewed" ]] || { rm -rf "$tmp"; return 1; }

  merged="$(jq -n \
    --argjson pending "$pending" \
    --argjson reviewed "$reviewed" '
      ($pending | map(. + {reviewStatus: "pending", _fromPending: true})) as $p
      | ($reviewed | map(. + {_fromReviewed: true})) as $r
      | ($p + $r)
      | group_by(.number)
      | map(
          reduce .[] as $item ({}; . * $item)
          | if ._fromPending then .reviewStatus = "pending" else . end
          | del(._fromPending, ._fromReviewed)
        )
    ')"

  # Parallel: enrich B-only PRs
  numbers="$(jq -r '.[] | select(.reviewStatus == null) | .number' <<< "$merged")"
  while IFS= read -r number; do
    [[ -n "$number" ]] || continue
    (
      status="$(my_latest_review_status "$slug" "$number")"
      printf '%s\t%s\n' "$number" "$status" >"$enrich_dir/$number"
    ) &
  done <<< "$numbers"
  wait

  if compgen -G "$enrich_dir/*" >/dev/null 2>&1; then
    status_map="$(cat "$enrich_dir"/* | jq -R -s '
      split("\n")
      | map(select(length > 0) | split("\t") | {(.[0]): .[1]})
      | add // {}
    ')"
  else
    status_map='{}'
  fi

  jq --argjson statuses "$status_map" '
    map(
      if .reviewStatus == null then
        .reviewStatus = ($statuses[.number | tostring] // "…")
      else . end
    )
  ' <<< "$merged"

  rm -rf "$tmp"
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
  printf "  ${SUBTEXT0}%-7s %-36s %-16s %-18s %-12s %-10s %s${NC}\n" \
    "PR #" "Title" "Author" "Review" "Updated" "Merge" "Link"
  printf "  ${SUBTEXT0}%-7s %-36s %-16s %-18s %-12s %-10s %s${NC}\n" \
    "──────" "────────────────────────────────────" \
    "────────────────" "──────────────────" "────────────" "──────────" \
    "────────────────────────────"

  while IFS=$'\t' read -r number title author review_status updated mergeable merge_status url; do
    updated_fmt="$(format_updated_at "$updated")"
    title_fmt="$(truncate "$title" 36)"
    author_fmt="$(truncate "@${author}" 16)"
    merge_fmt="$(merge_label "$mergeable" "$merge_status")"
    merge_c="$(merge_color "$merge_fmt")"
    review_c="$(review_color "$review_status")"
    printf "  ${TEXT}#%-6s${NC} ${TEXT}%-36s${NC} ${SUBTEXT1}%-16s${NC} ${review_c}%-18s${NC} ${SUBTEXT0}%-12s${NC} ${merge_c}%-10s${NC} ${TEAL}%s${NC}\n" \
      "$number" "$title_fmt" "$author_fmt" "$review_status" "$updated_fmt" "$merge_fmt" "$url"
  done < <(jq -r 'sort_by(.updatedAt) | reverse | .[] |
    "\(.number)\t\(.title)\t\(.author.login)\t\(.reviewStatus)\t\(.updatedAt)\t\(.mergeable)\t\(.mergeStateStatus)\t\(.url)"' <<< "$prs_json")

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

GH_USER="$(gh api user -q .login 2>/dev/null)" || {
  echo -e "${YELLOW}⚠ Failed to resolve GitHub username (gh auth?)${NC}"
  exit 1
}

feature_label="${FEATURE_NAME:-none}"
echo -e "${TEAL}→ PRs involving your review (feature: ${MAUVE}${feature_label}${TEAL})${NC}"
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
  echo -e "${GREEN}✓ No open PRs involving your review${NC}"
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

echo -e "${GREEN}✓ ${count} PR(s) involving your review${NC}"
[[ "$skipped" -gt 0 ]] && echo -e "${SUBTEXT0}  (${skipped} repo(s) skipped)${NC}"
exit 0
