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
# Three flat Catppuccin Mocha zones — no blending, every block is a real swatch:
#   0-20%  green  #a6e3a1
#   20-60% yellow #f9e2af
#   60%+   red    #f38ba8
# Each filled block takes the colour of its own position, so the bar bands as
# it fills. Same thresholds as pct_color, so bar and percentage always agree.
# Empty blocks are Mocha surface1 #45475a.
# Single source of truth for the 0-20 / 20-60 / 60+ zone colours.
# Takes a percentage (may be fractional), emits a Mocha truecolor escape.
zone_color() {
  local p="${1:-0}"
  local z
  z=$(awk "BEGIN{print ($p < 20) ? 0 : (($p < 60) ? 1 : 2)}")
  case "$z" in
    0) printf '%b' "$mocha_green"  ;;
    1) printf '%b' "$mocha_yellow" ;;
    *) printf '%b' "$mocha_red"    ;;
  esac
}

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
      local blkcol
      blkcol=$(zone_color "$pos")
      bar+=$(printf '%b█' "$blkcol")
    else
      bar+=$(printf '\e[38;2;69;71;90m░')
    fi
  done
  bar+="$c_reset"
  printf '%s' "$bar"
}

# ── Weekly pace bar (7 segments = 7 days) ─────────────────────────────────────
# Each segment is one day of the rolling 7-day window, split horizontally:
#   TOP half (green)  = quota used, mapped onto the 7 slots
#   BOTTOM half (gray)= days already elapsed in the window
# Green running past gray = over-using; gray past green = under-using.
# Echoes the pace delta on stdout line 2 so the caller can render it.
build_week_bar() {
  local wk_pct="${1:-0}"
  local wk_reset_epoch="${2:-}"
  local width=7
  local window_secs=604800
  local bg='\e[48;2;49;50;68m'          # #313244 surface0 — bar trough
  local fg_gray='\e[38;2;108;112;134m'  # #6c7086 overlay0 — elapsed days
  local fg_green='\e[38;2;166;227;161m' # #a6e3a1 green — quota used
  local fg_empty='\e[38;2;49;50;68m'
  local filled_usage elapsed_blocks=0 elapsed_pct=0

  filled_usage=$(awk "BEGIN{printf \"%.0f\", $wk_pct/100*$width}")
  (( filled_usage > width )) && filled_usage=$width

  if [[ -n "$wk_reset_epoch" ]]; then
    local now window_start elapsed_secs
    now=$(date +%s)
    window_start=$(( wk_reset_epoch - window_secs ))
    elapsed_secs=$(( now - window_start ))
    (( elapsed_secs < 0 )) && elapsed_secs=0
    (( elapsed_secs > window_secs )) && elapsed_secs=$window_secs
    elapsed_blocks=$(awk "BEGIN{printf \"%.0f\", $elapsed_secs/$window_secs*$width}")
    elapsed_pct=$(awk "BEGIN{printf \"%.0f\", $elapsed_secs/$window_secs*100}")
  fi

  local bar="" i
  for (( i=0; i<width; i++ )); do
    local used=0 elapsed=0
    (( i < filled_usage ))  && used=1
    (( i < elapsed_blocks )) && elapsed=1
    if   (( used && elapsed )); then
      bar+=$(printf '\e[48;2;108;112;134m%b▀' "$fg_green")
    elif (( used )); then
      bar+=$(printf '%b%b▀' "$bg" "$fg_green")
    elif (( elapsed )); then
      bar+=$(printf '%b%b▄' "$bg" "$fg_gray")
    else
      bar+=$(printf '%b%b▀' "$bg" "$fg_empty")
    fi
  done
  bar+="$c_reset"
  printf '%s\n' "$bar"
  printf '%s\n' "$(( ${wk_pct%.*} - elapsed_pct ))"
}

# ── Percentage colour (Catppuccin Mocha tiers) ────────────────────────────────
pct_color() {
  # Same 20/60 thresholds as the bar zones, so the number matches the blocks.
  zone_color "$(printf '%.0f' "${1:-0}")"
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

# 1. 󰉋 Repo / dir name — bold yellow
display_name=""
if [[ -n "$repo_name" ]]; then
  display_name="$repo_name"
elif [[ -n "$cwd" ]]; then
  display_name="$(basename "$cwd")"
fi
if [[ -n "$display_name" ]]; then
  out+=$(printf '%s%b%b%s%b' '󰉋 ' "$c_bold" "$mocha_yellow" "$display_name" "$c_reset")
fi

# 2. 󰘬 branch — bold sky/cyan in parentheses
if [[ -n "$branch" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%s%b%b(%s)%b' '󰘬 ' "$c_bold" "$mocha_sky" "$branch" "$c_reset")
fi

# 3. Context window — 󰍛 + 20-block zoned bar + coloured percentage
if [[ -n "$used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  used_int=$(printf '%.0f' "$used")
  bar=$(build_ctx_bar "$used_int")
  pctcol=$(pct_color "$used_int")
  out+="$(printf '%s' '󰍛 ')${bar} $(printf '%b%d%%%b' "$pctcol" "$used_int" "$c_reset")"
fi

# 4. Session cost — yellow
if [[ -n "$cost_usd" ]]; then
  cost_fmt=$(awk "BEGIN{printf \"\$%.3f\", $cost_usd}")
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%b%s%b' "$mocha_yellow" "$cost_fmt" "$c_reset")
fi

# 4b. Session limit (5-hour) — 󱎫 + 10-block gradient bar + coloured percentage + reset
if [[ -n "$sess_used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  sess_int=$(printf '%.0f' "$sess_used")
  sess_bar=$(build_ctx_bar "$sess_int" 10)
  sess_pctcol=$(pct_color "$sess_int")
  out+="$(printf '%s' '󱎫 ')${sess_bar} $(printf '%b%d%%%b' "$sess_pctcol" "$sess_int" "$c_reset")"
  if [[ -n "$sess_reset" ]]; then
    reset_str=$(fmt_reset "$sess_reset")
    [[ -n "$reset_str" ]] && out+="$(printf '%b%b 󰑐 %s%b' "$c_dim" "$mocha_overlay" "$reset_str" "$c_reset")"
  fi
fi

# 4c. Weekly limit (7-day) — 󰸗 + 7-segment pace bar (gray=days elapsed,
#     green=quota used) + coloured percentage + reset
if [[ -n "$wk_used" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  wk_int=$(printf '%.0f' "$wk_used")
  wk_out=$(build_week_bar "$wk_int" "$wk_reset")
  wk_bar=$(printf '%s' "$wk_out" | sed -n '1p')
  wk_pace=$(printf '%s' "$wk_out" | sed -n '2p')
  wk_pctcol=$(pct_color "$wk_int")
  out+="$(printf '%s' '󰸗 ')${wk_bar} $(printf '%b%d%%%b' "$wk_pctcol" "$wk_int" "$c_reset")"
  # Pace delta vs. elapsed time: ▲ = burning quota faster than the week passes
  if [[ -n "$wk_reset" && "$wk_pace" =~ ^-?[0-9]+$ ]]; then
    if   (( wk_pace >  2 )); then out+=$(printf ' %b▲%d%b'  "$mocha_peach" "$wk_pace"      "$c_reset")
    elif (( wk_pace < -2 )); then out+=$(printf ' %b▼%d%b'  "$mocha_green" "$(( -wk_pace ))" "$c_reset")
    else                          out+=$(printf ' %b≡%b'    "$mocha_overlay" "$c_reset")
    fi
  fi
  if [[ -n "$wk_reset" ]]; then
    wk_reset_str=$(fmt_reset "$wk_reset")
    [[ -n "$wk_reset_str" ]] && out+="$(printf '%b%b 󰑐 %s%b' "$c_dim" "$mocha_overlay" "$wk_reset_str" "$c_reset")"
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

# 6. 󰚩 model — pink/magenta
if [[ -n "$model" ]]; then
  [[ -n "$out" ]] && out+="$SEP"
  out+=$(printf '%s%b%s%b' '󰚩 ' "$mocha_pink" "$model" "$c_reset")
fi

printf '%b\n' "$out"
