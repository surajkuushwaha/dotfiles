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

2. Use stow to create symlinks. **Note**: Use the `--dotfiles` flag when your files already have dots in their names:
   ```bash
   # For individual packages
   stow --dotfiles -t ~ zsh
   stow --dotfiles -t ~ zellij

   # Or for all packages at once
   stow --dotfiles -t ~ */
   ```

### Troubleshooting

#### Issue: Stow creates `.zshrc.pre-oh-my-zsh` instead of `.zshrc`

This happens when Oh My Zsh has already created a `.zshrc` file. Solution:
1. Remove or backup the existing `.zshrc`: `mv ~/.zshrc ~/.zshrc.oh-my-zsh-backup`
2. Remove any incorrect symlinks: `rm ~/.zshrc.pre-oh-my-zsh`
3. Re-run stow with the `--dotfiles` flag: `stow --dotfiles -t ~ zsh`

#### Issue: Symlinks created without dots (e.g., `~/zshrc` instead of `~/.zshrc`)

This happens when you don't use the `--dotfiles` flag. Solution:
1. Unstow the package: `stow -D zsh`
2. Re-stow with the correct flag: `stow --dotfiles -t ~ zsh`

## GNU Stow Naming Convention

main file -> stow structure

~/.config/zellij -> zellij/.config/zellij
~/.zshrc -> zsh/.zshrc
