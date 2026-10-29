#!/usr/bin/env bash

input=$(cat)

printf '%s' "$input" | bash "$HOME/.claude/statusline-mocha.sh"
