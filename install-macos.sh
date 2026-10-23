#!/usr/bin/env bash
# Bootstrap a fresh Mac from this dotfiles repo.
# Safe to re-run: each step skips work that is already done.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "install-macos.sh only runs on macOS" >&2
  exit 1
fi

step "Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Finish the Command Line Tools install, then re-run this script."
  exit 0
fi

step "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

step "Brewfile"
brew bundle install --file="$DOTFILES/Brewfile"

step "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone() {
  [[ -d "$2" ]] || git clone --depth=1 "$1" "$2"
}

step "Zsh theme and plugins"
clone https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

step "Stow packages"
# Oh My Zsh drops a ~/.zshrc; ours lives in ~/.config/zsh via ZDOTDIR.
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi
mkdir -p "$HOME/.config"
(cd "$DOTFILES" && stow .)
stow --dotfiles -d "$DOTFILES" -t "$HOME" zshenv claude

step "tmux plugins"
clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
"$HOME/.config/tmux/plugins/tpm/bin/install_plugins" || echo "Skipped: press prefix + I inside tmux"

step "gh extensions"
if gh auth status >/dev/null 2>&1; then
  gh extension list | grep -q gh-dash || gh extension install dlvhdr/gh-dash
else
  echo "Skipped: run 'gh auth login', then 'gh extension install dlvhdr/gh-dash'"
fi

step "Spicetify"
if [[ ! -x "$HOME/.spicetify/spicetify" ]]; then
  curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
fi

step "Services"
brew services start sketchybar || true
brew services start borders || true

step "Done"
echo "Open a new terminal to load the zsh config."
