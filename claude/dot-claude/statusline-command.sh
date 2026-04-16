#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
five_hour_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Git branch
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "${cwd:-$(pwd)}" symbolic-ref --short HEAD 2>/dev/null)

# Prettify token count
prettify_tokens() {
  local t=$1
  if [[ "$t" -ge 1000000 ]]; then
    awk "BEGIN { printf \"%.0fM\", $t/1000000 }"
  elif [[ "$t" -ge 1000 ]]; then
    awk "BEGIN { printf \"%.0fk\", $t/1000 }"
  else
    echo "$t"
  fi
}

# Build segments
parts=()

if [[ -n "$branch" ]]; then
  parts+=("$branch")
fi

if [[ -n "$model" ]]; then
  parts+=("$model")
fi

if [[ -n "$used" ]]; then
  used_int=$(printf '%.0f' "$used")
  total=$((input_tokens + output_tokens))
  ctx_str="ctx:${used_int}%"
  if [[ "$total" -gt 0 ]]; then
    pretty=$(prettify_tokens "$total")
    ctx_str="ctx:${used_int}% (${pretty} tokens)"
  fi
  if [[ "$exceeds_200k" == "true" ]]; then
    ctx_str="${ctx_str} >200k!"
  fi
  parts+=("$ctx_str")
fi

if [[ -n "$five_hour_used" ]]; then
  five_hour_pct=$(printf '%.0f' "$five_hour_used")
  if [[ "$five_hour_used" -ge 95 && -n "$five_hour_resets" ]]; then
    reset_ist=$(TZ="Asia/Kolkata" date -r "$five_hour_resets" "+%I:%M %p IST")
    parts+=("5h:${five_hour_pct}% resets ${reset_ist}")
  else
    parts+=("5h:${five_hour_pct}%")
  fi
fi

if [[ -n "$seven_day_used" ]]; then
  seven_day_pct=$(printf '%.0f' "$seven_day_used")
  parts+=("7d:${seven_day_pct}%")
fi

if [[ -n "$cost_usd" ]]; then
  cost_fmt=$(awk "BEGIN { printf \"%.2f\", $cost_usd }")
  parts+=("\$${cost_fmt}")
fi

# Join with separator
result=""
for part in "${parts[@]}"; do
  if [[ -z "$result" ]]; then
    result="$part"
  else
    result="$result | $part"
  fi
done

echo "$result"
