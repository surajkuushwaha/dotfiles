#!/usr/bin/env bash
# Claude Code status line — Catppuccin Mocha + truecolor RGB gradient

input=$(cat)

# ── Data extraction ───────────────────────────────────────────────────────────
cwd=$(echo "$input"       | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"     | jq -r '.model.display_name // empty')
used=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
cost_usd=$(echo "$input"  | jq -r '.cost.total_cost_usd // empty')
sess_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
sess_reset=$(echo "$input"| jq -r '.rate_limits.five_hour.resets_at // empty')
wk_used=$(echo "$input"   | jq -r '.rate_limits.seven_day.used_percentage // empty')
wk_reset=$(echo "$input"  | jq -r '.rate_limits.seven_day.resets_at // empty')

# Git info (skip optional locks to avoid stalls)
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "${cwd:-$(pwd)}" symbolic-ref --short HEAD 2>/dev/null)

# Code velocity: lines added/removed in working tree vs HEAD
vel_add=0; vel_del=0
if [[ -n "$branch" ]]; then
  diff_stat=$(GIT_OPTIONAL_LOCKS=0 git -C "${cwd:-$(pwd)}" diff --numstat HEAD 2>/dev/null)
  if [[ -n "$diff_stat" ]]; then
    vel_add=$(echo "$diff_stat" | awk '{s+=$1} END {print s+0}')
    vel_del=$(echo "$diff_stat" | awk '{s+=$2} END {print s+0}')
  fi
fi

# ── ANSI helpers ─────────────────────────────────────────────────────────────
c_reset='\e[0m'
c_bold='\e[1m'
c_dim='\e[2m'

# Catppuccin Mocha palette
mocha_yellow='\e[38;2;249;226;175m'    # #f9e2af
mocha_sky='\e[38;2;137;220;235m'       # #89dceb
mocha_pink='\e[38;2;245;194;231m'      # #f5c2e7
mocha_green='\e[38;2;166;227;161m'     # #a6e3a1
mocha_red='\e[38;2;243;139;168m'       # #f38ba8
mocha_overlay='\e[38;2;108;112;134m'   # #6c7086
mocha_peach='\e[38;2;250;179;135m'     # #fab387

# ── Truecolor gradient block ──────────────────────────────────────────────────
# Gradient: green(0,200,80) → yellow(220,200,0) → red(220,40,20) across 0-100%
# Each filled block is coloured by its own position in the gradient.
# Empty blocks are dark gray rgb(60,60,60).
build_ctx_bar() {
  local pct="${1:-0}"
  local width="${2:-20}"
  local filled
  filled=$(awk "BEGIN{printf \"%.0f\", $pct/100*$width}")
  local bar=""
  for (( i=0; i<width; i++ )); do
    # colour position = centre of this block in 0-100 range
    local pos
    pos=$(awk "BEGIN{printf \"%.1f\", ($i+0.5)/$width*100}")
    if (( i < filled )); then
      local r g b
      local cmp
      cmp=$(awk "BEGIN{print ($pos <= 50) ? 1 : 0}")
      if (( cmp == 1 )); then
        r=$(awk "BEGIN{printf \"%.0f\", 0   + ($pos/50)*(220)}")
        g=200
        b=$(awk "BEGIN{printf \"%.0f\", 80  - ($pos/50)*80}")
      else
        r=220
        g=$(awk "BEGIN{printf \"%.0f\", 200 - (($pos-50)/50)*160}")
        b=$(awk "BEGIN{printf \"%.0f\", 0   + (($pos-50)/50)*20}")
      fi
      bar+=$(printf '\e[38;2;%d;%d;%dm█' "$r" "$g" "$b")
    else
      bar+=$(printf '\e[38;2;60;60;60m░')
    fi
  done
  bar+="$c_reset"
  printf '%s' "$bar"
}

# ── Usage emoji (changes by tier) ────────────────────────────────────────────
usage_emoji() {
  local pct_int
  pct_int=$(printf '%.0f' "${1:-0}")
  if   (( pct_int <  20 )); then printf '🟢'
  elif (( pct_int <  70 )); then printf '⚡'
  elif (( pct_int <  90 )); then printf '🔥'
  else                           printf '🚨'
  fi
}

# ── Percentage colour (Catppuccin Mocha tiers) ────────────────────────────────
pct_color() {
  local pct_int
  pct_int=$(printf '%.0f' "${1:-0}")
  if   (( pct_int <  20 )); then printf '\e[38;2;166;227;161m'  # green
  elif (( pct_int <  70 )); then printf '\e[38;2;249;226;175m'  # yellow
  elif (( pct_int <  90 )); then printf '\e[38;2;250;179;135m'  # peach
  else                          printf '\e[38;2;243;139;168m'   # red
  fi
}

# ── Reset countdown (epoch → "Xd Yh" / "Xh Ym") ──────────────────────────────
fmt_reset() {
  local target="${1:-}"
  [[ -z "$target" ]] && return
  local now diff d h m
  now=$(date +%s)
  diff=$(( target - now ))
  (( diff < 0 )) && diff=0
  d=$(( diff / 86400 )); h=$(( (diff % 86400) / 3600 )); m=$(( (diff % 3600) / 60 ))
  if   (( d > 0 )); then printf '%dd %dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh %dm' "$h" "$m"
  else                   printf '%dm' "$m"
  fi
}

# ── Dim pipe separator ────────────────────────────────────────────────────────
SEP=$(printf '%b' "${c_dim}${mocha_overlay} │ ${c_reset}")

# ── Assemble line ─────────────────────────────────────────────────────────────
out=""

# 1. Repo / dir name — bold yellow
display_name=""
if [[ -n "$repo_name" ]]; then
  display_name="$repo_name"
elif [[ -n "$cwd" ]]; then
  display_name="$(basename "$cwd")"
fi
if [[ -n "$display_name" ]]; then
  out+=$(printf '%b%b%s%b' "$c_bold" "$mocha_yellow" "$display_name" "$c_reset")
fi

# 2. 🌿 branch — bold sky/cyan in parentheses
if [[ -n "$branch" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%s%b%b(%s)%b' '🌿 ' "$c_bold" "$mocha_sky" "$branch" "$c_reset")
fi

# 3. 20-block gradient bar + emoji + coloured percentage
if [[ -n "$used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  used_int=$(printf '%.0f' "$used")
  bar=$(build_ctx_bar "$used_int")
  emoji=$(usage_emoji "$used_int")
  pctcol=$(pct_color "$used_int")
  out+="${bar}${emoji}$(printf '%b%d%%%b' "$pctcol" "$used_int" "$c_reset")"
fi

# 4. Session cost — yellow
if [[ -n "$cost_usd" ]]; then
  cost_fmt=$(awk "BEGIN{printf \"\$%.3f\", $cost_usd}")
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%b%s%b' "$mocha_yellow" "$cost_fmt" "$c_reset")
fi

# 4b. Session limit (5-hour) — ⏱ + 10-block gradient bar + coloured percentage + reset
if [[ -n "$sess_used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  sess_int=$(printf '%.0f' "$sess_used")
  sess_bar=$(build_ctx_bar "$sess_int" 10)
  sess_pctcol=$(pct_color "$sess_int")
  out+="$(printf '%s' '⏱ ')${sess_bar}$(printf '%b%d%%%b' "$sess_pctcol" "$sess_int" "$c_reset")"
  if [[ -n "$sess_reset" ]]; then
    reset_str=$(fmt_reset "$sess_reset")
    [[ -n "$reset_str" ]] && out+="$(printf '%b%b ⟳%s%b' "$c_dim" "$mocha_overlay" "$reset_str" "$c_reset")"
  fi
fi

# 4c. Weekly limit (7-day) — 📅 string only, coloured percentage + reset
if [[ -n "$wk_used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  wk_int=$(printf '%.0f' "$wk_used")
  wk_pctcol=$(pct_color "$wk_int")
  out+="$(printf '%s' '📅 ')$(printf '%bweek %d%%%b' "$wk_pctcol" "$wk_int" "$c_reset")"
  if [[ -n "$wk_reset" ]]; then
    wk_reset_str=$(fmt_reset "$wk_reset")
    [[ -n "$wk_reset_str" ]] && out+="$(printf '%b%b ⟳%s%b' "$c_dim" "$mocha_overlay" "$wk_reset_str" "$c_reset")"
  fi
fi

# 5. Code velocity — +lines in green, -lines in red
if (( vel_add > 0 || vel_del > 0 )); then
  [[ -n "$out" ]] && out+="$SEP"
  vel_str=""
  (( vel_add > 0 )) && vel_str+=$(printf '%b+%d%b' "$mocha_green" "$vel_add" "$c_reset")
  (( vel_add > 0 && vel_del > 0 )) && vel_str+=" "
  (( vel_del > 0 )) && vel_str+=$(printf '%b-%d%b' "$mocha_red"   "$vel_del" "$c_reset")
  out+="$vel_str"
fi

# 6. 🤖 model — pink/magenta
if [[ -n "$model" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%s%b%s%b' '🤖 ' "$mocha_pink" "$model" "$c_reset")
fi

printf '%b\n' "$out"
