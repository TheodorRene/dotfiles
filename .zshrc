MY_CUSTOM_ZSH=$HOME/dotfiles/zsh
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"
bindkey -e

autoload -Uz compinit
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
    compinit
else
    compinit -C
fi

source $MY_CUSTOM_ZSH/history.zsh
[ -s "$HOME/.nvm/nvm.sh" ] && \. "$HOME/.nvm/nvm.sh"
[ -s "$HOME/.nvm/bash_completion" ] && \. "$HOME/.nvm/bash_completion"
source $MY_CUSTOM_ZSH/path.zsh
source $MY_CUSTOM_ZSH/exports.zsh
source $MY_CUSTOM_ZSH/alias.zsh
source $MY_CUSTOM_ZSH/functions.zsh

# Defer heavier init until first prompt
autoload -Uz add-zsh-hook
__post_init() {
    if command -v fzf >/dev/null 2>&1; then
        source <(fzf --zsh)
    fi

    if command -v direnv >/dev/null 2>&1; then
        eval "$(direnv hook zsh)"
    fi

    [ -f "/Users/thca/.deno/env" ] && . "/Users/thca/.deno/env"

    if [ -f "/Users/thca/.ghcup/env" ]; then
        . "/Users/thca/.ghcup/env"
    fi

    if [ -f '/Users/thca/dev/google-cloud-sdk/path.zsh.inc' ]; then
        . '/Users/thca/dev/google-cloud-sdk/path.zsh.inc'
    fi

    if [ -f '/Users/thca/dev/google-cloud-sdk/completion.zsh.inc' ]; then
        . '/Users/thca/dev/google-cloud-sdk/completion.zsh.inc'
    fi

    add-zsh-hook -d precmd __post_init
    unset -f __post_init
}
add-zsh-hook precmd __post_init

. /usr/share/autojump/autojump.sh

_build_prompt() {
    local nix=''
    [[ -n "$IN_NIX_SHELL" ]] && nix=' %F{yellow}[nix]%f'

    local git=''
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        local dirty=''
        git diff --quiet 2>/dev/null || dirty='*'
        git diff --cached --quiet 2>/dev/null || dirty='*'
        git="%F{green} ${branch}${dirty}%f"
    fi

    PROMPT="%F{blue}%~%f${git}${nix}
> "
}
add-zsh-hook precmd _build_prompt


# github copilot cli x
# eval "$(github-copilot-cli alias -- "$0")"
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="theodorc"



plugins=(
    extract
    fzf
    git
    autojump
    sudo
)
#source $ZSH/oh-my-zsh.sh

# Add completion to custom pdf command
zstyle ':completion:*:*:pdf:*' file-patterns '*.pdf'
zstyle ':completion:*:*:(nvim|vim):*' ignored-patterns '*.pdf'

# Conditionally open less based on size of input
# I like having small git diffs not in a pager
export LESS="-RFX"

# bun completions
[ -s "/home/theodorc/.bun/_bun" ] && source "/home/theodorc/.bun/_bun"

#defaults write -g NSWindowShouldDragOnGesture YES
