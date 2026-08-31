#!/usr/bin/env bash
# Claude Code statusline: daily.dev headline on line 1, Catppuccin Mocha on line 2.
#
# Both consumers read the same JSON payload from stdin, so it is captured once
# and replayed to each. Neither script is modified; statusline-mocha.sh stays
# exactly as it is (symlinked into ~/Personal/dotfiles).
#
# The daily.dev path is globbed, not pinned: the plugin cache directory carries
# the version, so `ls -td .../*/ | head -1` always resolves the newest install
# and survives plugin updates.

input=$(cat)

daily_dir=$(ls -td "$HOME/.claude/plugins/cache/daily-dev/daily-dev"/*/ 2>/dev/null | head -1)
if [ -n "$daily_dir" ] && [ -f "${daily_dir}statusline/statusline.mjs" ]; then
    # daily.dev prefixes its line with the model name whenever the payload
    # carries one, which duplicates what the mocha line already shows. Drop the
    # key from ITS copy of the payload rather than regexing the model out of the
    # rendered ANSI — the prefix is data-driven, so removing the input removes
    # the prefix. Mocha still gets the untouched payload below.
    daily_input=$(printf '%s' "$input" | jq -c 'del(.model)' 2>/dev/null)
    [ -n "$daily_input" ] || daily_input=$input

    # Never let a daily.dev failure take the mocha line down with it.
    headline=$(printf '%s' "$daily_input" | node "${daily_dir}statusline/statusline.mjs" 2>/dev/null)
    # Trailing blank line puts breathing room between the headline and the
    # mocha line below. Emitted only when there is a headline, so a daily.dev
    # failure leaves no orphan gap above the mocha line.
    [ -n "$headline" ] && printf '%s\n\n' "$headline"
fi

printf '%s' "$input" | bash "$HOME/.claude/statusline-mocha.sh"
