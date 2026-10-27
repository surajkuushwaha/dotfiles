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

step "Brewfile ($(grep -cE '^(brew|cask|vscode|go) ' "$DOTFILES/Brewfile") entries)"
# brew bundle runs `npm install -g` without node on PATH (env: node: No such file),
# so npm entries are left out here and installed one by one below.
brewfile="$(mktemp)"
grep -v '^npm ' "$DOTFILES/Brewfile" > "$brewfile"
# --verbose streams each install's download progress instead of one line per package.
brew bundle install --verbose --file="$brewfile"
rm -f "$brewfile"

step "npm globals"
# One at a time, so a package whose native build fails doesn't block the rest.
command -v node >/dev/null 2>&1 || brew install node
npm_failed=""
for pkg in $(grep -E '^npm "' "$DOTFILES/Brewfile" | cut -d'"' -f2); do
  npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 || npm install -g "$pkg" || npm_failed="$npm_failed $pkg"
done
[[ -z "$npm_failed" ]] || echo "npm packages that failed to install:$npm_failed"

step "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # ZSH is set because the installer otherwise picks $ZDOTDIR/ohmyzsh, i.e. this repo.
  ZSH="$HOME/.oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone() {
  [[ -d "$2" ]] || git clone --progress --depth=1 "$1" "$2"
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
  # Runs from a temp dir because the installer writes install.log to the current directory.
  (cd "$(mktemp -d)" && curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh)
  # The installer appends its own PATH line; .zshrc already has one.
  perl -0pi -e 's/\n+export PATH=\$PATH:\Q$ENV{HOME}\E\/\.spicetify\n\z/\n/' "$DOTFILES/zsh/.zshrc"
fi

step "App settings"
# Exported with: defaults export <domain> macos/<domain>.plist
for plist in "$DOTFILES"/macos/*.plist; do
  domain="$(basename "$plist" .plist)"
  osascript -e "quit app id \"$domain\"" 2>/dev/null || true
  defaults import "$domain" "$plist"
done

step "SketchyBar (SbarLua + app icon map)"
# SbarLua is the Lua module the config runs on; it has no brew formula.
if [[ ! -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]]; then
  sbarlua_dir="$(mktemp -d)"
  git clone --depth 1 --quiet https://github.com/FelixKratz/SbarLua.git "$sbarlua_dir"
  (cd "$sbarlua_dir" && make install)
fi
# icon_map.lua is gitignored and must match the installed font-sketchybar-app-font version.
icon_map="$DOTFILES/sketchybar/helpers/spaces_util/icon_map.lua"
if [[ ! -f "$icon_map" ]]; then
  font_version="$(brew list --cask --versions font-sketchybar-app-font | awk '{print $2}')"
  curl -fsSL "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v$font_version/icon_map.lua" -o "$icon_map" ||
    echo "Could not fetch icon_map.lua; space app icons fall back to the built-in list."
fi

step "Services"
brew services start sketchybar || true
brew services start borders || true

step "Done"
echo "Open a new terminal to load the zsh config."
