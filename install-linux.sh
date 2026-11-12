#!/usr/bin/env bash
# Bootstrap a Linux (Ubuntu/Debian) dev box from this dotfiles repo: terminal tools only.
# Safe to re-run: each step skips work that is already done.
# Run by infra/shared/cloud-init on a new VM's first boot; run by hand on an existing one.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
# Linked into ~/.config. macOS-only packages (aerospace, sketchybar, ghostty, ...) are left out.
CONFIG_PACKAGES=(zsh tmux git gh gh-dash nvim atuin zellij)

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

if [[ "$(uname -s)" != "Linux" ]] || ! command -v apt-get >/dev/null 2>&1; then
  echo "install-linux.sh needs Linux with apt (Ubuntu/Debian)" >&2
  exit 1
fi

arch="$(uname -m)" # x86_64 or aarch64
deb_arch="$(dpkg --print-architecture)"

step "apt packages"
sudo apt-get update -qq
sudo apt-get install -y -qq zsh tmux git stow curl unzip build-essential ripgrep fd-find bat jq eza htop
# Ubuntu ships bat as batcat and fd as fdfind
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

step "Neovim"
# apt's Neovim is too old; use the official release
if ! command -v nvim >/dev/null 2>&1; then
  nvim_dir="nvim-linux-${arch/aarch64/arm64}"
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$nvim_dir.tar.gz" | sudo tar -xz -C /opt
  sudo ln -sf "/opt/$nvim_dir/bin/nvim" /usr/local/bin/nvim
fi

step "fzf"
# apt's fzf is too old for `fzf --zsh` (needs 0.48+)
if [[ ! -x "$HOME/.fzf/bin/fzf" ]]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --bin
fi
sudo ln -sf "$HOME/.fzf/bin/fzf" /usr/local/bin/fzf

step "GitHub CLI"
if ! command -v gh >/dev/null 2>&1; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$deb_arch signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi

step "atuin"
# Release tarball instead of the setup script, which edits shell rc files
if ! command -v atuin >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/atuinsh/atuin/releases/latest/download/atuin-$arch-unknown-linux-gnu.tar.gz" | tar -xz -C "$tmp"
  sudo install -m 755 "$tmp"/atuin-*/atuin /usr/local/bin/atuin
  rm -rf "$tmp"
fi

step "zellij"
if ! command -v zellij >/dev/null 2>&1; then
  curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-$arch-unknown-linux-musl.tar.gz" |
    sudo tar -xz -C /usr/local/bin zellij
fi

step "fnm + Node LTS"
FNM_DIR="$HOME/.local/share/fnm"
if [[ ! -x "$FNM_DIR/fnm" ]]; then
  # --skip-shell: .zshrc already sets up fnm
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
fi
export PATH="$FNM_DIR:$PATH"
eval "$(fnm env --shell bash)"
fnm list | grep -q lts-latest || fnm install --lts

step "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # ZSH is set because the installer otherwise picks $ZDOTDIR/ohmyzsh, i.e. this repo.
  ZSH="$HOME/.oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone() {
  [[ -d "$2" ]] || git clone --depth=1 "$1" "$2"
}

step "Zsh theme and plugins"
clone https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

step "Link config packages"
# Same result as `stow .` on macOS (one symlink per package dir), limited to CONFIG_PACKAGES.
mkdir -p "$HOME/.config"
for pkg in "${CONFIG_PACKAGES[@]}"; do
  [[ -d "$DOTFILES/$pkg" ]] || continue
  target="$HOME/.config/$pkg"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mv "$target" "$target.backup"
  fi
  ln -sfn "$DOTFILES/$pkg" "$target"
done
# Oh My Zsh drops a ~/.zshrc; ours lives in ~/.config/zsh via ZDOTDIR.
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi
# Run from $HOME so the repo's .stowrc (targets ~/.config) is not picked up.
(cd "$HOME" && stow --dotfiles -d "$DOTFILES" -t "$HOME" zshenv)

step "tmux plugins"
clone https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
"$HOME/.config/tmux/plugins/tpm/bin/install_plugins" || echo "Skipped: press prefix + I inside tmux"

step "gh extensions"
if gh auth status >/dev/null 2>&1; then
  gh extension list | grep -q gh-dash || gh extension install dlvhdr/gh-dash
else
  echo "Skipped: run 'gh auth login', then 'gh extension install dlvhdr/gh-dash'"
fi

step "Default shell"
zsh_path="$(command -v zsh)"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  sudo chsh -s "$zsh_path" "$USER"
fi

step "Done"
echo "Open a new shell (or reconnect) to load the zsh config."
