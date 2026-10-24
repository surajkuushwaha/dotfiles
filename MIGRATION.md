# Migrate to the new Mac

Moves `~/CultureX` (with stashes, worktrees, unpushed commits, `.env` files) and the CultureX Claude Code history from the old Mac (user `suraj`) to the new Mac (user `surajkushwaha`). Everything else comes from this repo.

New Mac: `surajkushwaha@Surajs-MacBook-Air-2.local`. Old Mac: `suraj`.

## On the old Mac

### 1. Push the dotfiles

Commit anything you want to keep first (`git status` shows what is left), then:

```bash
cd ~/Personal/dotfiles
git status
git push
```

### 2. Quit Claude Code

Close every Claude Code session so the history files stop changing.

## On the new Mac

### 3. Turn on Remote Login

System Settings → General → Sharing → **Remote Login** → on. The page shows the address, e.g. `ssh surajkushwaha@Surajs-MacBook-Air-2.local`. Keep both Macs on the same Wi-Fi.

### 4. Install the dotfiles

```bash
xcode-select --install          # wait for it to finish
git clone https://github.com/surajkuushwaha/dotfiles.git ~/Personal/dotfiles
~/Personal/dotfiles/install-macos.sh
brew install rsync
```

If `brew bundle` stops on an app that is already installed, run `brew install --cask --adopt <name>` and re-run the script.

### 5. Log in to GitHub and add a new SSH key

```bash
gh auth login
ssh-keygen -t ed25519
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Company Mac"
git -C ~/Personal/dotfiles remote set-url origin git@github.com:surajkuushwaha/dotfiles.git
```

## On the old Mac

### 6. Copy CultureX

```bash
brew install rsync
rsync -aH --info=progress2 \
  --exclude node_modules --exclude .next --exclude .turbo --exclude .DS_Store \
  ~/CultureX surajkushwaha@Surajs-MacBook-Air-2.local:~/
```

About 10 GB before excludes. Re-running it only copies what changed.

### 7. Copy Claude Code history, skills and hooks

Conversation folders are named after the project path, so they get renamed from `-Users-suraj-` to `-Users-surajkushwaha-`, and the old path inside them is rewritten.

```bash
NEW=surajkushwaha@Surajs-MacBook-Air-2.local

# conversations + memory, CultureX folders only
ssh $NEW 'mkdir -p ~/.claude/projects'
cd ~/.claude/projects
for d in -Users-suraj-CultureX*; do
  rsync -a "$d/" "$NEW:~/.claude/projects/${d/-Users-suraj-/-Users-surajkushwaha-}/"
done
ssh $NEW 'cd ~/.claude/projects && LC_ALL=C find . -name "*.jsonl" -exec sed -i "" "s#/Users/suraj/#/Users/surajkushwaha/#g" {} +'

# up-arrow prompt history, CultureX prompts only
jq -c 'select(.project | startswith("/Users/suraj/CultureX"))' ~/.claude/history.jsonl \
  | sed 's#/Users/suraj/#/Users/surajkushwaha/#g' \
  | ssh $NEW 'cat >> ~/.claude/history.jsonl'

# skills (cx-* live in ~/.agents/skills, ~/.claude/skills links to them) and hooks
rsync -aH ~/.agents $NEW:~/
rsync -aH ~/.claude/skills ~/.claude/hooks ~/.claude/agents $NEW:~/.claude/
```

Running the `sed` twice is harmless: `/Users/surajkushwaha/` does not contain `/Users/suraj/`.

Skip `~/.claude.json` if the company Mac uses a different Claude account; re-add MCP servers there instead.

## On the new Mac

### 8. Repair the worktrees

Worktrees store absolute paths to their main repo.

```zsh
for repo in ~/CultureX/repos/*(/); do
  wts=( ~/CultureX/features/*/${repo:t}(N) )
  (( $#wts )) && git -C $repo worktree repair $wts
done
git -C ~/CultureX/repos/cx-saas-server worktree list
```

Every path in the list should start with `/Users/surajkushwaha/`.

### 9. Fix old paths in the dotfiles

The RTK hook and two permission rules in `claude/dot-claude/settings.json` point at `/Users/suraj/`, so Claude Code hooks fail until this is fixed.

```bash
cd ~/Personal/dotfiles
git grep -n '/Users/suraj/'
git grep -l '/Users/suraj/' | xargs sed -i '' 's#/Users/suraj/#/Users/surajkushwaha/#g'
git grep -n '/Users/suraj/' || echo "all fixed"
git commit -am "fix: update home paths for new Mac" && git push
```

### 10. Reinstall dependencies

`node_modules` was not copied. In each repo you work in:

```bash
cd ~/CultureX/repos/<repo> && pnpm install   # or npm / yarn / bun
```

### 11. Check nothing was lost

Run on **both** Macs and compare. Every line should match.

```bash
for g in $(find ~/CultureX -maxdepth 4 -name .git); do
  r=${g%/.git}
  echo "$(git -C $r stash list | wc -l) stashes  $(git -C $r status --porcelain | wc -l) dirty  ${r#$HOME/}"
done
```

Then `cd ~/CultureX/repos/cx-saas-server && claude --resume`; your old conversations should be listed.

### 12. Clean up

Turn Remote Login back off (System Settings → General → Sharing).

## Not carried over

- `~/Personal` repos (only the dotfiles come from GitHub).
- Shell history. To bring it, from the old Mac:
  ```bash
  rsync -a ~/Personal/dotfiles/zsh/.zsh_history surajkushwaha@Surajs-MacBook-Air-2.local:~/Personal/dotfiles/zsh/
  rsync -a ~/.local/share/atuin surajkushwaha@Surajs-MacBook-Air-2.local:~/.local/share/
  ```
- Claude conversations from non-CultureX folders.
