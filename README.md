# dotfiles

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). Every package is
a plain folder that gets symlinked into `~/.config/` (or `~/` for a few). Edit files here; the
symlinks make the change live.

Theme everywhere: Catppuccin Mocha.

## New Mac

```bash
git clone https://github.com/surajkuushwaha/dotfiles.git ~/Personal/dotfiles
~/Personal/dotfiles/install-macos.sh
```

The script is safe to re-run. It installs, in order:

1. Xcode Command Line Tools and Homebrew
2. Everything in `Brewfile`
3. Oh My Zsh, Powerlevel10k, zsh plugins
4. Stow links for all packages
5. tmux plugins, gh-dash, Spicetify
6. App settings from `macos/*.plist`
7. SketchyBar extras: SbarLua and the app icon map
8. Starts the `sketchybar` and `borders` services

Then do the manual steps in [After install](#after-install).

## Packages

| Package | Linked to | Notes |
|---------|-----------|-------|
| `aerospace/` | `~/.config/aerospace/` | Tiling WM; triggers SketchyBar workspace events |
| `atuin/` | `~/.config/atuin/` | Shell history |
| `borders/` | `~/.config/borders/` | Window borders (JankyBorders) |
| `claude/` | `~/.claude/` | Stowed separately (see below) |
| `gh/`, `gh-dash/` | `~/.config/gh/`, `~/.config/gh-dash/` | `gh/hosts.yml` not tracked |
| `ghostty/` | `~/.config/ghostty/` | Terminal |
| `git/` | `~/.config/git/` | Global gitignore |
| `nvim/` | `~/.config/nvim/` | |
| `opencode/` | `~/.config/opencode/` | |
| `sketchybar/` | `~/.config/sketchybar/` | Lua bar, see [`sketchybar/README.md`](sketchybar/README.md) |
| `spicetify/` | `~/.config/spicetify/` | Spotify theming |
| `tmux/` | `~/.config/tmux/` | |
| `wezterm/`, `zellij/` | `~/.config/…` | |
| `zed/` | `~/.config/zed/` | |
| `zsh/` | `~/.config/zsh/` | `ZDOTDIR` set by `zshenv/` |
| `zshenv/` | `~/.zshenv` | Stowed separately |
| `glazewm/`, `yasb/` | `~/.config/…` | Windows only |

Not stowed: `automation/` (scripts run from the repo), `macos/` (plist exports),
`Brewfile`, `install-macos.sh`, docs.

## Everyday commands

```bash
cd ~/Personal/dotfiles

stow .                                         # link all ~/.config packages
stow --dotfiles -d ~/Personal/dotfiles -t ~ zshenv claude   # link ~/ packages
stow -R .                                      # relink after adding/removing files
stow -D .                                      # remove all links

brew bundle --file=Brewfile                    # install anything missing
brew bundle dump --force --describe --file=Brewfile   # save currently installed apps

sketchybar --reload                            # after editing sketchybar/
aerospace reload-config                        # after editing aerospace/
```

### Add a new app config

1. Move the folder in: `mv ~/.config/foo ~/Personal/dotfiles/foo`
2. Link it: `stow .`
3. Add it to the [Packages](#packages) table, and to `Brewfile` if it needs installing.

### Save macOS app settings

```bash
defaults export <domain> macos/<domain>.plist
```

Strip machine-specific keys (window sizes, timestamps, bookmarks, notes) before committing.
`install-macos.sh` imports every file in `macos/`.

## After install

- **SketchyBar**: System Settings → Control Center → *Automatically hide and show the menu
  bar* → **Always**. Allow `sketchybar` in Privacy & Security → Accessibility.
  Full dependency list: [`sketchybar/README.md`](sketchybar/README.md).
- **AeroSpace**: allow it in Privacy & Security → Accessibility, then launch it once.
- `gh auth login` (writes the untracked `gh/hosts.yml`).
- Open a new terminal to load the zsh config.

## Troubleshooting

**`stow .` reports a conflict.** A real file sits where a link should go. Either delete it, or
pull it into the repo with `stow --adopt .` and review `git diff`.

**`zshenv` / `claude` not linked.** `.stowrc` ignores them on purpose. Use the `-d … -t ~`
command above.

**Oh My Zsh created `~/.zshrc`.** Remove it; the real config is `~/.config/zsh/.zshrc` via
`ZDOTDIR`.

**SketchyBar blank or missing.** Run it in the foreground to see errors:
`brew services stop sketchybar && sketchybar`.

## How Stow is set up

`.stowrc` makes `stow .` target `~/.config/` and ignores the non-config files. Each top-level
folder becomes `~/.config/<folder>`:

```
~/.config/ghostty/config        → ghostty/config
~/.config/sketchybar/           → sketchybar/        (whole folder linked)
~/.config/zsh/.zshrc            → zsh/.zshrc
~/.zshenv                       → zshenv/dot-zshenv  (dot- prefix, --dotfiles)
~/.claude/settings.json         → claude/dot-claude/settings.json
```

Linux note: the zsh setup also works on Ubuntu (`sudo apt install stow zsh fzf bat eza`;
`bat` is called `batcat` there).
