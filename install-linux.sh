#!/usr/bin/env bash
# Install and sync a Linux (Ubuntu/Debian) dev box from this dotfiles repo: terminal tools only.
# First run installs everything. Every later run syncs: pulls the dotfiles, upgrades apt
# packages, updates release-binary tools when a newer release exists, updates zsh/tmux
# plugins, and re-links config. Safe to re-run any time.
# Run by infra/shared/cloud-init on a new VM's first boot; run by hand afterwards to sync.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
# Linked into ~/.config. macOS-only packages (aerospace, sketchybar, ghostty, ...) are left out.
CONFIG_PACKAGES=(zsh tmux git gh gh-dash nvim atuin zellij)
APT_PACKAGES=(zsh tmux git stow curl unzip build-essential ripgrep fd-find bat jq eza htop neofetch)

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$1"; }

if [[ "$(uname -s)" != "Linux" ]] || ! command -v apt-get >/dev/null 2>&1; then
  echo "install-linux.sh needs Linux with apt (Ubuntu/Debian)" >&2
  exit 1
fi

arch="$(uname -m)" # x86_64 or aarch64
deb_arch="$(dpkg --print-architecture)"

# Latest release version of a GitHub repo, without the leading "v".
# Follows the /releases/latest redirect instead of the API, so there is no rate limit.
latest_release() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed -E 's|.*/tag/v?||'
}

# Installed version of a command (first x.y.z in its --version output), or empty.
installed_version() {
  command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

# Clone a repo, or fast-forward it if already cloned.
clone_or_pull() {
  if [[ -d "$2/.git" ]]; then
    git -C "$2" pull --ff-only --quiet || echo "Could not update $2 (local changes?)"
  else
    git clone --depth=1 --quiet "$1" "$2"
  fi
}

step "Dotfiles repo"
# Pull first; if the pull changed this script, re-run the new version.
if [[ -z "${DOTFILES_SYNCED:-}" && -d "$DOTFILES/.git" ]]; then
  if [[ -n "$(git -C "$DOTFILES" status --porcelain --untracked-files=no)" ]]; then
    echo "Local changes in $DOTFILES; skipping pull"
  else
    before="$(git -C "$DOTFILES" rev-parse HEAD)"
    git -C "$DOTFILES" pull --ff-only --quiet || echo "Could not pull $DOTFILES"
    if [[ "$(git -C "$DOTFILES" rev-parse HEAD)" != "$before" ]]; then
      echo "Dotfiles updated; restarting with the new script"
      DOTFILES_SYNCED=1 exec "$DOTFILES/install-linux.sh" "$@"
    fi
  fi
fi

step "apt packages"
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${APT_PACKAGES[@]}"
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
sudo apt-get autoremove -y -qq
# Ubuntu ships bat as batcat and fd as fdfind
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

step "GitHub CLI"
# Installed from GitHub's apt repo; later runs upgrade it with the apt step above.
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

step "Neovim"
# apt's Neovim is too old; use the official release
latest="$(latest_release neovim/neovim)"
if [[ "$(installed_version nvim)" != "$latest" ]]; then
  nvim_dir="nvim-linux-${arch/aarch64/arm64}"
  sudo rm -rf "/opt/$nvim_dir"
  curl -fsSL "https://github.com/neovim/neovim/releases/download/v$latest/$nvim_dir.tar.gz" | sudo tar -xz -C /opt
  sudo ln -sf "/opt/$nvim_dir/bin/nvim" /usr/local/bin/nvim
  echo "Neovim $latest"
else
  echo "Neovim $latest (up to date)"
fi

step "fzf"
# apt's fzf is too old for `fzf --zsh` (needs 0.48+)
clone_or_pull https://github.com/junegunn/fzf.git "$HOME/.fzf"
"$HOME/.fzf/install" --bin >/dev/null
sudo ln -sf "$HOME/.fzf/bin/fzf" /usr/local/bin/fzf
echo "fzf $(installed_version fzf)"

step "atuin"
# Release tarball instead of the setup script, which edits shell rc files
latest="$(latest_release atuinsh/atuin)"
if [[ "$(installed_version atuin)" != "$latest" ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/atuinsh/atuin/releases/download/v$latest/atuin-$arch-unknown-linux-gnu.tar.gz" | tar -xz -C "$tmp"
  sudo install -m 755 "$tmp"/atuin-*/atuin /usr/local/bin/atuin
  rm -rf "$tmp"
  echo "atuin $latest"
else
  echo "atuin $latest (up to date)"
fi

step "zellij"
latest="$(latest_release zellij-org/zellij)"
if [[ "$(installed_version zellij)" != "$latest" ]]; then
  curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v$latest/zellij-$arch-unknown-linux-musl.tar.gz" |
    sudo tar -xz -C /usr/local/bin zellij
  echo "zellij $latest"
else
  echo "zellij $latest (up to date)"
fi

step "fnm + Node LTS"
FNM_DIR="$HOME/.local/share/fnm"
export PATH="$FNM_DIR:$PATH"
latest="$(latest_release Schniz/fnm)"
if [[ "$(installed_version fnm)" != "$latest" ]]; then
  # --skip-shell: .zshrc already sets up fnm
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$FNM_DIR" --skip-shell
fi
eval "$(fnm env --shell bash)"
node_lts="$(fnm ls-remote --lts | tail -1 | awk '{print $1}')"
fnm list | grep -q "$node_lts" || fnm install "$node_lts"
fnm default "$node_lts"
echo "fnm $(installed_version fnm), Node $node_lts (default)"

step "corepack (pnpm, yarn)"
# Node 25+ no longer bundles corepack, so install it from npm into the default Node.
# fnm exec: this shell's fnm PATH may predate the Node just installed.
fnm exec --using="$node_lts" -- npm install -g --silent corepack@latest
fnm exec --using="$node_lts" -- corepack enable
echo "corepack $(fnm exec --using="$node_lts" -- corepack --version)"

step "Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  # ZSH is set because the installer otherwise picks $ZDOTDIR/ohmyzsh, i.e. this repo.
  ZSH="$HOME/.oh-my-zsh" RUNZSH=no KEEP_ZSHRC=yes CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  git -C "$HOME/.oh-my-zsh" pull --ff-only --quiet || echo "Could not update Oh My Zsh"
fi

step "Zsh theme and plugins"
clone_or_pull https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

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
(cd "$HOME" && stow --dotfiles --restow -d "$DOTFILES" -t "$HOME" zshenv)

step "tmux plugins"
clone_or_pull https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
"$HOME/.config/tmux/plugins/tpm/bin/install_plugins" >/dev/null || echo "Skipped install: press prefix + I inside tmux"
"$HOME/.config/tmux/plugins/tpm/bin/update_plugins" all >/dev/null || echo "Skipped update: press prefix + U inside tmux"

step "gh extensions"
if gh auth status >/dev/null 2>&1; then
  gh extension list | grep -q gh-dash || gh extension install dlvhdr/gh-dash
  gh extension upgrade --all || true
else
  echo "Skipped: run 'gh auth login', then re-run this script"
fi

step "Default shell"
zsh_path="$(command -v zsh)"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  sudo chsh -s "$zsh_path" "$USER"
fi

step "Done"
echo "Open a new shell (or reconnect) to load any config changes."
