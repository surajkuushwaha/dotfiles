# Enable Powerlevel10k instant prompt. Should stay close to the top of $ZDOTDIR/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
# load theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# plugins
plugins=(git z zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh
source $ZDOTDIR/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

# Set up fzf key bindings and fuzzy completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source <(fzf --zsh)



# zsh plugin

# open zed code editor using zed .
alias zed="open -a /Applications/Zed.app -n"

# start the dev server - manly for the node or ts projects
ddev() {
  if [ -f "pnpm-lock.yaml" ]; then
    doppler run --watch -- pnpm run dev
  fi
  if [ -f "bun.lock" ]; then
    doppler run --watch -- bun run dev
  fi
  if [ -f "package-lock.json" ]; then
    doppler run --watch -- npm run dev
  fi
}
dev() {
  if [ -f "pnpm-lock.yaml" ]; then
    pnpm run dev
  fi
  if [ -f "bun.lock" ]; then
    bun run dev
  fi
  if [ -f "package-lock.json" ]; then
    npm run dev
  fi
}
alias inano='nano $(fzf --preview="batcat --color=always {}")'

# eza aliasesd
alias l="eza -l --icons --git -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"


# git alias
alias gbc='git checkout -b'
alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias glo='git log --oneline'
alias igbc='git checkout $(git for-each-ref --sort=-committerdate --format "%(refname:short)" refs/heads/ | fzf)'
alias igpc='gh pr checkout'
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gcoall='git checkout -- .'
alias gr='git remote -v'
alias gre='git reset'
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"

# docker aliases
alias dcu='docker compose up'
alias dcd='docker compose down'

# process aliases
# show memory usage of top 21 processes
psm() {
  ps -eo pid,%cpu,rss,comm | sort -rk 3 | head -n 21 | \
  awk 'NR==1 {printf "%-8s %-10s %-10s %s\n", "PID", "CPU(%)", "RAM(MB)", "COMMAND"; next}
       {printf "PID: %-8s CPU: %-10s %%  RAM: %-10.2f MB  PATH: %s\n", $1, $2, $3/1024, $4}'
}
# show cpu usage of top 21 processes
psc() {
  ps -eo pid,%cpu,rss,comm | sort -rk 2 | head -n 21 | \
  awk 'NR==1 {printf "%-8s %-10s %-10s %s\n", "PID", "CPU(%)", "RAM(MB)", "COMMAND"; next}
       {printf "PID: %-8s CPU: %-10s %%  RAM: %-10.2f MB  PATH: %s\n", $1, $2, $3/1024, $4}'
}

# tmux aliases
tmuxcopy() {
    local pane

    pane=$(
        tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name}' |
        fzf --prompt="Select pane: " --height=40%
    ) || return

    pane=$(echo "$pane" | awk '{print $1}')

    tmux capture-pane -p -S - -t "$pane" | pbcopy

    echo "✅ Copied logs from $pane to clipboard"
}
alias tcopy='tmuxcopy'

q() {
  pi -p "$*"
}



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH=$HOME/.local/bin:$PATH

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf "$@" --preview 'tree -C {} | head -200' ;;
    *)            fzf "$@" ;;
  esac
}

# NODE VERSION MANAGERS
# fnm
FNM_PATH="/opt/homebrew/opt/fnm/bin"
if [ -d "$FNM_PATH" ]; then
  eval "`fnm env`"
fi
# ---

sk() {
  local script="$HOME/Personal/dotfiles/automation/current-project.sh"
  "$script" "$@"
}

cx() {
  local script="$HOME/Personal/dotfiles/CultureX/start-dev.sh"
  "$script" "$@"
}

export PATH=$PATH:$HOME/.spicetify

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
eval "$(atuin init zsh)"
\

# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}
