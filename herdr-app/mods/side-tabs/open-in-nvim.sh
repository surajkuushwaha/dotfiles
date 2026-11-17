#!/bin/sh
# Called by the side panel's yazi: opens the picked files in one nvim, as a new
# tab in the active Herdr space, named after the first file.
[ "$#" -gt 0 ] || exit 0
herdr=$(command -v herdr-app || echo "$HOME/.local/bin/herdr-app")
argv=$(jq -cn '["nvim"] + $ARGS.positional' --args "$@")
"$herdr" do tab.new --name "$(basename "$1")" --folder "$(dirname "$1")" --argv "$argv" >/dev/null
