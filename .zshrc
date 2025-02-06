zstyle ':completion:*' rehash true

MY_CUSTOM_ZSH=$HOME/dotfiles/zsh

source $MY_CUSTOM_ZSH/path.zsh
source $MY_CUSTOM_ZSH/exports.zsh
source $MY_CUSTOM_ZSH/alias.zsh
source $MY_CUSTOM_ZSH/functions.zsh


[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion


# github copilot cli x
# eval "$(github-copilot-cli alias -- "$0")"
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="theodorc"



#Plugins
plugins=(
    extract
    fzf
    git
    last-working-dir
    autojump
    sudo
)
source $ZSH/oh-my-zsh.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Add completion to custom pdf command
zstyle ':completion:*:*:pdf:*' file-patterns '*.pdf'
zstyle ':completion:*:*:(nvim|vim):*' ignored-patterns '*.pdf'



# Conditionally open less based on size of input
# I like having small git diffs not in a pager
export LESS="-RFX"



# bun completions
[ -s "/home/theodorc/.bun/_bun" ] && source "/home/theodorc/.bun/_bun"

eval "$(direnv hook zsh)"

#defaults write -g NSWindowShouldDragOnGesture YES

. "/Users/thca/.deno/env"

[ -f "/Users/thca/.ghcup/env" ] && . "/Users/thca/.ghcup/env" # ghcup-env
