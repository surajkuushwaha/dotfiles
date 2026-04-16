# dotfiles

## Installation

### Prerequisites

1. Install GNU Stow:
   ```bash
   # On macOS
   brew install stow

   # On Ubuntu/Debian
   sudo apt install stow
   ```

2. Clone this repository:
   ```bash
   git clone <repository-url> ~/Personal/dotfiles
   cd ~/Personal/dotfiles
   ```

### Zsh Dependencies

Install the following dependencies for the zsh configuration:

1. **Oh My Zsh**:
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

2. **Powerlevel10k Theme**:
   ```bash
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
   ```

3. **Zsh Plugins**:
   ```bash
   # zsh-syntax-highlighting
   git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

   # zsh-autosuggestions
   git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
   ```

4. **FZF (Fuzzy Finder)**:
   ```bash
   # On macOS
   brew install fzf
   $(brew --prefix)/opt/fzf/install

   # On Ubuntu/Debian
   git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
   ~/.fzf/install
   ```

5. **Additional Tools**:
   ```bash
   # eza (modern ls replacement)
   # On macOS
   brew install eza

   # On Ubuntu/Debian
   sudo apt install -y gpg
   sudo mkdir -p /etc/apt/keyrings
   wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
   echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
   sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
   sudo apt update
   sudo apt install -y eza

   # batcat (cat with syntax highlighting) - for fzf preview
   # On macOS
   brew install bat

   # On Ubuntu/Debian
   sudo apt install bat
   # Note: On Ubuntu/Debian, the command is 'batcat' instead of 'bat'
   ```

6. **Optional: Node Version Managers** (if needed):
   ```bash
   # fnm (Fast Node Manager) - for macOS
   brew install fnm

   # bun
   curl -fsSL https://bun.sh/install | bash

   # pnpm
   curl -fsSL https://get.pnpm.io/install.sh | sh -
   ```

### Setting up dotfiles with Stow

1. **Important**: If you have Oh My Zsh installed, it creates its own `.zshrc` file. Back it up first:
   ```bash
   mv ~/.zshrc ~/.zshrc.backup
   ```

2. Deploy dotfiles using stow. The `.stowrc` file configures `stow .` to target `~/.config/`:
   ```bash
   # Deploy all XDG packages to ~/.config/
   stow .

   # Deploy home-root packages (zshenv, claude) — must use -d to bypass .stowrc
   stow --dotfiles -d ~/Personal/dotfiles -t ~ zshenv claude
   ```

### Troubleshooting

#### Issue: `stow .` conflicts with existing config files

If a config file already exists (not a symlink), use `--adopt`:
```bash
stow --adopt .
```
This moves existing files into the dotfiles repo and replaces them with symlinks.

#### Issue: zshenv/claude packages not deploying

These packages are ignored by `.stowrc`. Deploy them separately with `-d` flag to bypass `.stowrc`:
```bash
stow --dotfiles -d ~/Personal/dotfiles -t ~ zshenv claude
```

## GNU Stow Naming Convention

`.stowrc` targets `~/.config/`. Each package dir maps to `~/.config/<package>/`:

```
~/.config/ghostty/config  → ghostty/config
~/.config/zellij/config.kdl → zellij/config.kdl
~/.config/tmux/tmux.conf  → tmux/tmux.conf
~/.config/zsh/.zshrc      → zsh/.zshrc (via ZDOTDIR)
~/.zshenv                 → zshenv/dot-zshenv (dot- prefix convention)
~/.claude/settings.json   → claude/dot-claude/settings.json
```
