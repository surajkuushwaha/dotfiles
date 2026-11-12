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

Packages ignored by `.stowrc`: automation, zshenv, claude, README.md, CLAUDE.md, Brewfile, install-macos.sh, macos, infra.

`macos/<domain>.plist`: app settings from `defaults export`, imported by `install-macos.sh`. Strip machine-specific and personal keys (window sizes, timestamps, bookmarks, notes) before committing.

Fresh Mac bootstrap: `./install-macos.sh` (Brewfile, Oh My Zsh, stow, tmux plugins, gh-dash, spicetify).

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
| `claude/` | `~/.claude/settings.json`, `keybindings.json`, `statusline-*.sh` | Uses `dot-` prefix, stowed separately. `hooks/` (rtk, herdr) and `skills/` (links to `~/.agents/skills`) are tool-managed, not tracked |
| `herdr-app/` | `~/.config/herdr-app/` | Herdr app: `settings.json`, `keys.json`, `themes/`, own layouts/mods (`mods/cx-features` = cmd-k feature switcher, builds spaces via `automation/culturex/herdr-feature.sh`), `sounds/`. App-managed files (AGENTS.md, `.d.ts`, shipped mods/layouts, state) gitignored |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | |
| `aerospace/` | `~/.config/aerospace/aerospace.toml` | Triggers `aerospace_workspace_change` for SketchyBar |
| `borders/` | `~/.config/borders/bordersrc` | |
| `sketchybar/` | `~/.config/sketchybar/` | Lua (SbarLua) config from Efterklang/sketchybar; deps in `sketchybar/README.md`, user settings in `settings.lua` |
| `glazewm/` | `~/.config/glazewm/config.yaml` | Windows |
| `yasb/` | `~/.config/yasb/` | Windows |
| `automation/` | Not stowed — run from the repo | `lib/` shared helpers, `personal/` (`sk`), `culturex/` (`cx`) |
| `infra/` | Not stowed | OpenTofu IaC for cloud dev workspaces: `shared/` (cloud-init), `<cloud>/workspace/` roots. State and `*.tfvars` gitignored |

## Infra Guardrails

`infra/` is in a public repo. Code is public, values are not.

- Commit: `.tf` files, `*.tfvars.example` (placeholders only), `shared/cloud-init.yaml` (no tokens), README/notes, `.terraform.lock.hcl` (pins provider versions).
- Never commit: `*.tfstate*` (IPs, resource IDs, secrets in plain text), `*.tfvars`, `.terraform/`, service-account JSON keys. `infra/.gitignore` blocks these; never weaken it.
- No hardcoded project ID, email, IP allowlist, or SSH public key in `.tf` files. Declare a variable; real value goes only in `terraform.tfvars`.
- Secrets (Tailscale auth keys, API tokens) go through env vars (`TF_VAR_<name>`) or a secret manager, marked `sensitive = true`. Never in cloud-init, `.tf`, or `*.tfvars.example`.
- Auth via `gcloud auth application-default login`. Do not create or download service-account keys.
- Run `gitleaks detect` before every commit touching `infra/`. A committed secret stays in git history: rotate it immediately, do not just delete the file.
- Never run `tofu apply` or `tofu destroy` without showing `tofu plan` output and getting explicit approval.
- Work (CultureX) infra, remote state, CI, or multiple environments → separate private repo, not `infra/`.

## Zsh Stack

Oh My Zsh + Powerlevel10k theme. Plugins: zsh-syntax-highlighting, zsh-autosuggestions, fzf. Uses eza (ls replacement), bat (cat replacement), fnm (Node version manager).

## Theme

Catppuccin Mocha across tools (zsh syntax highlighting, atuin, ghostty).
