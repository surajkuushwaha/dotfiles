# ZDOTDIR points here, so ~/.zprofile (where the Homebrew installer writes this) is never read.
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
# Docker Desktop CLI (it writes this to ~/.zprofile, which is never read).
[[ -d "$HOME/.docker/bin" ]] && export PATH="$PATH:$HOME/.docker/bin"
