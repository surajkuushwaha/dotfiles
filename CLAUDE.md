# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo managed with [GNU Stow](https://www.gnu.org/software/stow/). Follows omerxx/dotfiles pattern: flat package dirs, `.stowrc` targets `~/.config`.

## Stow Convention

`.stowrc` configures `stow .` to target `~/.config/`. Two deployment commands:

```bash
# XDG packages → ~/.config/
stow .

# Home-root packages → ~/ (must use -d to bypass .stowrc)
stow --dotfiles -d ~/Personal/dotfiles -t ~ zshenv claude
```

Packages ignored by `.stowrc`: automation, zshenv, claude, README.md, CLAUDE.md.

## Package Layout

| Package | Target | Notes |
|---------|--------|-------|
| `zsh/` | `~/.config/zsh/.zshrc`, `.p10k.zsh`, `.zsh/` | ZDOTDIR set via zshenv |
| `zshenv/` | `~/.zshenv` | Bootstraps `ZDOTDIR=$HOME/.config/zsh` |
| `tmux/` | `~/.config/tmux/tmux.conf` | tmux 3.1+ XDG support |
| `ghostty/` | `~/.config/ghostty/config` | |
| `zellij/` | `~/.config/zellij/config.kdl` | |
| `atuin/` | `~/.config/atuin/config.toml`, themes | |
| `git/` | `~/.config/git/ignore` | Global gitignore |
| `gh/` | `~/.config/gh/config.yml` | `hosts.yml` NOT tracked (auth tokens) |
| `gh-dash/` | `~/.config/gh-dash/config.yml` | GitHub dashboard TUI |
| `nvim/` | `~/.config/nvim/init.lua` | |
| `zed/` | `~/.config/zed/settings.json`, `keymap.json`, themes | `conversations/` and `prompts/` not tracked |
| `spicetify/` | `~/.config/spicetify/config-xpui.ini`, themes | `CustomApps/` not tracked |
| `claude/` | `~/.claude/settings.json`, `statusline-command.sh` | Uses `dot-` prefix, stowed separately |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | |
| `glazewm/` | `~/.config/glazewm/config.yaml` | Windows |
| `yasb/` | `~/.config/yasb/` | Windows |
| `automation/` | Not stowed — run from the repo | `lib/` shared helpers, `personal/` (`sk`), `culturex/` (`cx`) |

## Zsh Stack

Oh My Zsh + Powerlevel10k theme. Plugins: zsh-syntax-highlighting, zsh-autosuggestions, fzf. Uses eza (ls replacement), bat (cat replacement), fnm (Node version manager).

## Theme

Catppuccin Mocha across tools (zsh syntax highlighting, atuin, ghostty).
