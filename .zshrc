
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
path+=$HOME/bin
path+=$HOME/.local/bin
path+=/var/lib/snapd/snap/bin

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
    stack
)

source $ZSH/oh-my-zsh.sh

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

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
alias py="python"
alias sys="systemctl"
alias pacupgrade="sudo pacman -Syyu"
alias pacsearch="sudo pacman -Ss"
alias pacinstall="sudo pacman -S"
alias ssh_insecure="ssh -oKexAlgorithms=+diffie-hellman-group1-sha1"
alias dc="cd"
alias cp="cp -n"
alias vpn="sudo openconnect -bq --user=$USER vpn.ntnu.no"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Add completion to custom pdf command
zstyle ':completion:*:*:pdf:*' file-patterns '*.pdf'

export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/nvim

man(){
    command man $1 || $_ --help
}

wifi_pass(){
    sudo grep -oP '^psk=\K\w+' /etc/NetworkManager/system-connections/$(nmcli -t -f name connection show --active | head -n1).nmconnection
}

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin"
[ -f "/home/theodorc/.ghcup/env" ] && source "/home/theodorc/.ghcup/env" # ghcup-env

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
