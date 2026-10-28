# SketchyBar

Lua config based on **[Efterklang/sketchybar](https://github.com/Efterklang/sketchybar)**
(imported at commit `545bd0c`). Runs on [SbarLua](https://github.com/FelixKratz/SbarLua),
not shell plugins. Upstream Q&A lives in [`docs.md`](docs.md).

Local changes from upstream:

| File | Change |
|------|--------|
| `settings.lua` | `WINDOW_MANAGER = "aerospace"`, `chat` (QQ/WeChat) disabled, `SPACES.ID_STYLE = nil` (numbers, not Greek letters) |
| `helpers/init.lua` | SbarLua path uses `$HOME` instead of `/Users/$USER` |
| `helpers/.gitignore` | Ignores generated `spaces_util/icon_map.lua` |
| `init.lua` | `stats_provider` exec moved after `require("items")`; before, startup often hung in `pclose` with an empty bar |
| `items/front_app/front_app.lua` | App name in the bar center |
| `items/calendar/calendar.lua` | Time only, date line removed |
| `settings.lua` modules | Right side trimmed to netspeed, RAM, CPU, time |
| `items/spaces/window_managers/aerospace.lua` | Registers `aerospace_workspace_change` event (upstream never did, so focus highlight never moved); click switches by workspace name |
| `helpers/spaces_util/sbar_util.lua` | `add_space_item(..., "item")` creates plain items for AeroSpace, so native Mission Control space changes don't reset the highlight |

## Install on a new Mac

`./install-macos.sh` at the repo root does all of this. Manual steps:

### 1. Packages (all in the root `Brewfile`)

```bash
brew tap felixkratz/formulae
brew tap joncrangle/tap
brew install sketchybar lua jq switchaudio-osx media-control imagemagick
brew install joncrangle/tap/sketchybar-system-stats
brew install --cask font-sketchybar-app-font font-recursive-mono-nerd-font
```

| Package | Used by |
|---------|---------|
| `sketchybar` | The bar itself |
| `lua` | Runs `sketchybarrc` |
| `jq` | Music artwork parsing |
| `switchaudio-osx` | Volume popup: output device picker |
| `media-control` | Music item: now playing, play/pause, next/prev |
| `imagemagick` | Music item: album art resize |
| `sketchybar-system-stats` | CPU, memory, netspeed graphs (`stats_provider` binary) |
| `font-sketchybar-app-font` | App icons in spaces |
| `font-recursive-mono-nerd-font` | Icon and label font (`RecMonoCasual Nerd Font`) |

If `font-sketchybar-app-font` fails with "already a Font", delete the old manual copy first:
`rm ~/Library/Fonts/sketchybar-app-font.ttf`.

### 2. SbarLua (not in Homebrew)

Installs `sketchybar.so` to `~/.local/share/sketchybar_lua/`:

```bash
git clone --depth 1 https://github.com/FelixKratz/SbarLua.git /tmp/sbarlua
(cd /tmp/sbarlua && make install)
```

### 3. App icon map (optional, gitignored)

Gives space icons for every app the font knows. Without it, only the built-in list in
`helpers/spaces_util/app_icons.lua` is used. Version must match the installed font:

```bash
v=$(brew list --cask --versions font-sketchybar-app-font | awk '{print $2}')
curl -fsSL "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v$v/icon_map.lua" \
  -o ~/Personal/dotfiles/sketchybar/helpers/spaces_util/icon_map.lua
```

### 4. Link and start

```bash
cd ~/Personal/dotfiles && stow .        # ~/.config/sketchybar -> dotfiles/sketchybar
brew services restart sketchybar
```

### 5. macOS settings

- **System Settings → Control Center → Automatically hide and show the menu bar: Always**,
  so the native menu bar does not overlap the bar.
- **Privacy & Security → Accessibility**: allow `sketchybar` (front app menus, `helpers/menus`).
- Xcode Command Line Tools: `helpers/menus/menus.c` is compiled with `clang` on first launch
  into `helpers/menus/bin/` (gitignored).

## AeroSpace integration

Lives in `../aerospace/aerospace.toml` (unchanged by this package):

- `exec-on-workspace-change` triggers `aerospace_workspace_change` with `FOCUSED_WORKSPACE`.
  `items/spaces/window_managers/aerospace.lua` subscribes to it for the highlight.
- Space app icons refresh every 5 s from `aerospace list-windows`.
- Workspaces are read once at startup (`aerospace list-workspaces --all`). Reload after
  adding a workspace.

To use native macOS spaces instead, set `WINDOW_MANAGER = "macos_native"` in `settings.lua`.

## Customize

Everything user-facing is in **`settings.lua`**:

| Setting | Values |
|---------|--------|
| `THEME` | `catppuccin_mocha` (default), `catppuccin_latte`, `rose_pine`, `tokyo_night`, `nord_light` |
| `PRESET` | `gnix` (floating, rounded) or `compact` (flush, like native bar) |
| `MODULES.<name>.enable` | Toggle each item |
| `FONT` | Icon and label font family |
| `WIFI.PROXY_APP` | App name shown and opened from the wifi popup VPN row |

Themes live in `themes/`, items in `items/<name>/`, icons in `icons.lua`.

## Debug

```bash
sketchybar --reload                       # apply changes
brew services stop sketchybar && sketchybar   # run in foreground, see errors
tail -f ~/.cache/sketchybar/sbar.log      # LOG:info output
```

`module 'sketchybar' not found` means SbarLua is missing (step 2).

## Update from upstream

```bash
git clone --depth 1 https://github.com/Efterklang/sketchybar /tmp/efk
rsync -a --exclude .git --exclude readme.md --exclude install.sh /tmp/efk/ ~/Personal/dotfiles/sketchybar/
git -C ~/Personal/dotfiles diff sketchybar   # re-apply the local changes listed above
```
