# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git z zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh
source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
# Set up fzf key bindings and fuzzy completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source <(fzf --zsh)

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"



# now load zsh-syntax-highlighting plugin

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias dev="npm run dev"
alias ddev="doppler run --watch  -- npm run dev"
alias pdev="pnpm dev"
alias inano='nano $(fzf --preview="batcat --color=always {}")'
alias ls="eza --icons=always"


# git alias
alias gbc='git checkout -b'
alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias glo='git log --oneline'
alias igbc='git checkout $(git for-each-ref --sort=-committerdate --format "%(refname:short)" refs/heads/ | fzf)'


wooshOrigin(){
        git checkout -b $1 &&
        git push -u origin HEAD
}




# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh




# bun completions
[ -s "/home/suraj/.bun/_bun" ] && source "/home/suraj/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pnpm
export PNPM_HOME="/home/suraj/.local/share/pnpm"
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


alias cxlog='log_commits'
# Function to log commits in specified repos for a given date
# Example usage:
# log_commits 2025-03-03
log_commits() {
    # Check if date is provided
    if [ -z "$1" ]; then
        echo "Please provide a date in format YYYY-MM-DD"
        return 1
    fi
    
    # Input date in IST
    local input_date="$1"
    local email="suraj.kushwaha@culturex.in"
    if [ -n "$2" ]; then
        email="$2"
    fi
    
    # Convert IST date to UTC date range
    # IST is UTC+5:30, so subtract 5:30 hours for start and end of day
    local start_date=$(date -u -d "$input_date 00:00:00 IST -5 hours -30 minutes" +"%Y-%m-%d %H:%M:%S")
    local end_date=$(date -u -d "$input_date 23:59:59 IST -5 hours -30 minutes" +"%Y-%m-%d %H:%M:%S")

    echo $start_date
    echo $end_date
    
    # List of repositories
    local repos=(
        "/home/suraj/CultureX/repos/cx-saas-server"
        "/home/suraj/CultureX/repos/cx-creator-services"
        "/home/suraj/CultureX/repos/cx-analytics-backend"
        "/home/suraj/CultureX/repos/cx-saas-dashboard"
        "/home/suraj/CultureX/repos/saas-super-admin"
    )
    
    # Loop through each repository
    for repo in "${repos[@]}"; do
        if [ -d "$repo/.git" ]; then
            # echo "---"
            # Get repo name from path
            local repo_name=$(basename "$repo")
            
            # Change to repository directory
            pushd "$repo" > /dev/null
            
            # List commits within date range by the specified email
            local commits=$(git log --all --since="$start_date" --until="$end_date" --author="$email" --pretty=format:"[%h] [%an] [%ad] [%s] [%b]" --date=iso --branches)
            
            if [ -n "$commits" ]; then
                echo "[$repo_name] [$input_date] [$email]"
                
                # Process each commit
                echo "$commits" | while IFS= read -r commit_line; do
                    # Extract commit hash
                    local commit_hash=$(echo "$commit_line" | awk -F'[][]' '{print $2}')
                    
                    # Get commit message
                    local commit_msg=$(echo "$commit_line" | awk -F'[][]' '{print $8}')
                    
                    # Get branch for this commit
                    local branches=$(git branch --contains "$commit_hash" | sed 's/^\*\?\s*//')
                    
                    # If no local branches contain this commit, check remote branches
                    if [ -z "$branches" ]; then
                        branches=$(git branch -r --contains "$commit_hash" | sed 's/^\*\?\s*//' | sed 's/origin\///')
                    fi
                    
                    # If still no branches, mark as detached
                    if [ -z "$branches" ]; then
                        branches="detached"
                    fi
                    
                    # Print branch and commit info
                    echo "[$branches] : $commit_msg"
                done
            else
                echo "[$repo_name] [$input_date] [$email]"
                echo "No commits found"
            fi
            
            popd > /dev/null
            echo "---"
        else
            # echo "---"
            echo "Repository not found or not a git repository: $repo"
            echo "---"
        fi
    done
}

# export AWS_PROFILE=default

# export SSH_AUTH_SOCK=/home/suraj/snap/bitwarden/current/.bitwarden-ssh-agent.sock


# NODE VERSION MANAGERS 

# fnm
FNM_PATH="/opt/homebrew/opt/fnm/bin"
if [ -d "$FNM_PATH" ]; then
  eval "`fnm env`"
fi

# nvm
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

cx() {
  local script="$HOME/Personal/dotfiles/CultureX/start-dev.sh"
  "$script" "$@"
}

export PATH=$PATH:/Users/suraj/.spicetify
