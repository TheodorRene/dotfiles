
# Path to your oh-my-zsh installation.
 export ZSH="$HOME/.oh-my-zsh"
 path+=$HOME/bin

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME2="~/dotfiles/theodorc.zsh-theme"
ZSH_THEME="theodorc"

#Plugins
plugins=(
    git
    wd
    catimg
    last-working-dir
    fzf
    extract
    sudo
    docker
)

source $ZSH/oh-my-zsh.sh

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"
setopt EXTENDED_HISTORY

# ALIAS
alias takeover="tmux detach -a"
alias lr="ls -ltrh"
alias cass="mosh cassarossa.samfundet.no"
alias shut="sudo shutdown now"
alias clip="xclip -selection c"
alias svenv="source venv/bin/activate"
alias dsize="du -h --max-depth=1 | sort -h"
alias bc="bc -lq"
alias sugit="sudo -E git"
alias suvim="sudo -E vim"
alias vim="nvim"
alias vimnote="vim $(date +"%m_%d_%Y").md"
alias lock="xscreensaver-command -lock"
alias ukenr="date +%V"
alias dir="ls -d */"
alias ports="sudo lsof -i -P -n | grep LISTEN"
alias cat="bat"
alias lfile="$(ls -tr $HOME/Downloads | tail -n1)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/nvim


#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin:$HOME/.npm-global/bin"
#source /home/theodorc/.ghcup/env
[ -f "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"

export PATH=$PATH:/home/theodorc/bin
