
# Path to your oh-my-zsh installation.
 export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="blinks"

#Plugins
plugins=(
    git
    wd
    catimg
)

source $ZSH/oh-my-zsh.sh

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

alias takeover="tmux detach -a"
alias lr="ls -ltrh"

