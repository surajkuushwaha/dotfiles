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

### 5. Log in to GitHub as `cx-suraj`

`cx-suraj` is the default account on this Mac: plain `git@github.com:` URLs use its key, so there is no `work` host alias like on the old Mac. The personal account gets added later (see the end of this guide).

```bash
gh auth login --hostname github.com --git-protocol ssh --web   # sign in as cx-suraj

ssh-keygen -t ed25519 -C cx-suraj -f ~/.ssh/id_ed25519_cx
gh ssh-key add ~/.ssh/id_ed25519_cx.pub --title "CultureX MacBook Air"

cat >> ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_cx
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
EOF

ssh -T git@github.com    # should say: Hi cx-suraj!
```

The dotfiles stay on the HTTPS URL they were cloned with until the personal account is set up.

## On the old Mac

### 6. Copy CultureX

macOS ships openrsync at `/usr/bin/rsync`, which rejects `--info=progress2`. If `/usr/bin` comes before `/opt/homebrew/bin` in your PATH, the alias makes steps 6–7 use Homebrew's rsync.

```bash
brew install rsync
alias rsync=/opt/homebrew/bin/rsync
rsync --version | head -1     # should say: rsync  version 3.x
rsync -aH --info=progress2 \
  --exclude node_modules --exclude .next --exclude .turbo --exclude .DS_Store \
  ~/CultureX surajkushwaha@Surajs-MacBook-Air-2.local:~/
```

About 10 GB before excludes. Re-running it only copies what changed.

### 7. Copy Claude Code history, skills and hooks

Conversation folders are named after the project path, so they get renamed from `-Users-suraj-` to `-Users-surajkushwaha-`, and the old path inside them is rewritten.

Open one shared SSH connection first, so the password is typed once instead of for every command:

```bash
NEW=surajkushwaha@Surajs-MacBook-Air-2.local
nssh() { ssh -o ControlPath=/tmp/cm-newmac "$@"; }   # reuses the shared connection
ssh -o ControlMaster=yes -o ControlPath=/tmp/cm-newmac -o ControlPersist=20m -fN $NEW
```

Then copy:

```bash
# conversations + memory, CultureX folders only.
# Folder names start with "-", so the "./" stops rsync reading them as options.
nssh $NEW 'mkdir -p ~/.claude/projects'
cd ~/.claude/projects
for d in -Users-suraj-CultureX*; do
  rsync -a -e "ssh -o ControlPath=/tmp/cm-newmac" "./$d/" "$NEW:.claude/projects/${d/-Users-suraj-/-Users-surajkushwaha-}/"
done
nssh $NEW 'cd ~/.claude/projects && LC_ALL=C grep -rlI /Users/suraj/ ./-Users-surajkushwaha-CultureX* | xargs sed -i "" "s#/Users/suraj/#/Users/surajkushwaha/#g"'

# up-arrow prompt history, CultureX prompts only.
# This appends, so it only runs while the new Mac has no history yet.
lines=$(nssh $NEW 'f=~/.claude/history.jsonl; [ -f $f ] && wc -l < $f || echo 0' | tr -d ' ')
if [[ -z $lines ]]; then
  echo "could not reach the new Mac, history not copied"
elif [[ $lines == 0 ]]; then
  jq -c 'select(.project | startswith("/Users/suraj/CultureX"))' ~/.claude/history.jsonl \
    | sed 's#/Users/suraj/#/Users/surajkushwaha/#g' \
    | nssh $NEW 'cat >> ~/.claude/history.jsonl'
else
  echo "history.jsonl already on the new Mac ($lines lines), skipped"
fi

# skills (cx-* live in ~/.agents/skills, ~/.claude/skills links to them) and hooks
rsync -aH -e "ssh -o ControlPath=/tmp/cm-newmac" ~/.agents $NEW:
rsync -aH -e "ssh -o ControlPath=/tmp/cm-newmac" ~/.claude/skills ~/.claude/hooks ~/.claude/agents $NEW:.claude/

nssh $NEW 'ls ~/.claude/projects | grep -c "^-Users-surajkushwaha-CultureX"'   # should match: ls ~/.claude/projects | grep -c "^-Users-suraj-CultureX"
ssh -o ControlPath=/tmp/cm-newmac -O exit $NEW          # close the shared connection
```

Running this block twice is harmless: rsync only copies changes, the history step skips itself, and the `sed` can't match twice because `/Users/surajkushwaha/` does not contain `/Users/suraj/`.

Skip `~/.claude.json` if the company Mac uses a different Claude account; re-add MCP servers there instead.

## On the new Mac

### 8. Repair the worktrees

Worktrees store absolute paths to their main repo, in both directions. `git worktree repair` stops with "invalid path" when those paths don't exist, so rewrite them directly.

```zsh
# worktree side: each worktree's .git file (files only, so real clones are skipped)
for f in ~/CultureX/features/*/*/.git(.N); do
  sed -i '' 's#/Users/suraj/#/Users/surajkushwaha/#' $f
done
# main repo side: each repo's list of its worktrees
for f in ~/CultureX/repos/*/.git/worktrees/*/gitdir(N); do
  sed -i '' 's#/Users/suraj/#/Users/surajkushwaha/#' $f
done

for r in ~/CultureX/repos/*(/); do git -C $r worktree list; done
```

Every path should start with `/Users/surajkushwaha/`. The `cx-creator-services` worktree under `~/orca/workspaces/` was not copied and shows as prunable. Remove its leftover entry (files are not touched):

```bash
git -C ~/CultureX/repos/cx-creator-services worktree prune --dry-run -v   # should list only the orca one
git -C ~/CultureX/repos/cx-creator-services worktree prune -v
```

### 8b. Point remotes at `github.com`

On the old Mac remotes used the `work` alias (`git@work:cx-suraj/cx-saas-server.git`). Rewrite them to `git@github.com:cx-suraj/cx-saas-server.git`. Worktrees share their main repo's remotes, so only the main repos need it.

```zsh
for repo in ~/CultureX/repos/*(/) ~/CultureX/exp/*(/N); do
  [[ -d $repo/.git ]] || continue
  for name in $(git -C $repo remote); do
    url=$(git -C $repo remote get-url $name)
    [[ $url == git@work:* ]] && git -C $repo remote set-url $name "git@github.com:${url#git@work:}"
  done
done
grep -rl 'git@work:' ~/CultureX/*/*/.git/config || echo "no work remotes left"
git -C ~/CultureX/repos/cx-saas-server fetch origin
```

Your work email (`suraj.kushwaha@culturex.in`) is set per repo in each `.git/config`, so it came along with the copy.

### 9. Fix old paths in the dotfiles

`claude/dot-claude/settings.json` no longer hardcodes a home folder: the RTK hook runs `$HOME/.claude/hooks/rtk-rewrite.sh` and the two rules say `~/CultureX/...`, so it works on both Macs. Pull it, then check nothing else still points at the old home:

```bash
cd ~/Personal/dotfiles
git pull
git grep -n '/Users/suraj/' || echo "no old paths left"
```

Test the RTK hook (should print `rtk git status`):

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | ~/.claude/hooks/rtk-rewrite.sh | jq -r '.hookSpecificOutput.updatedInput.command'
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

## Later: add the personal account

`cx-suraj` keeps `github.com`. The personal account gets its own host alias, `github-personal`.

```bash
gh auth login --hostname github.com --git-protocol ssh --web   # sign in as surajkuushwaha
gh auth switch -u cx-suraj                                      # keep cx-suraj as the default

ssh-keygen -t ed25519 -C surajkuushwaha -f ~/.ssh/id_ed25519_personal
GH_TOKEN=$(gh auth token -u surajkuushwaha) gh ssh-key add ~/.ssh/id_ed25519_personal.pub --title "CultureX MacBook Air"

cat >> ~/.ssh/config <<'EOF'
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_personal
  IdentitiesOnly yes
EOF

ssh -T git@github-personal    # should say: Hi surajkuushwaha!
git -C ~/Personal/dotfiles remote set-url origin git@github-personal:surajkuushwaha/dotfiles.git
git -C ~/Personal/dotfiles push
```

Clone personal repos as `git@github-personal:surajkuushwaha/<repo>.git`. `gh` already picks the right account per folder (`automation/personal/gh-account.zsh`: `cx-suraj` in `~/CultureX`, personal elsewhere).

## Not carried over

- `~/Personal` repos (only the dotfiles come from GitHub).
- Shell history. To bring it, from the old Mac:
  ```bash
  rsync -a ~/Personal/dotfiles/zsh/.zsh_history surajkushwaha@Surajs-MacBook-Air-2.local:~/Personal/dotfiles/zsh/
  rsync -a ~/.local/share/atuin surajkushwaha@Surajs-MacBook-Air-2.local:~/.local/share/
  ```
- Claude conversations from non-CultureX folders.
