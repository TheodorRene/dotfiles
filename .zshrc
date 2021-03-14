
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
path+=$HOME/bin
path+=$HOME/.local/bin
path+=/var/lib/snapd/snap/bin

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME2="~/dotfiles/theodorc.zsh-theme"
ZSH_THEME="theodorc"

# If you want to do machine specific config
[[ $HOST == "abba" ]] && export MACHINE="desktop"
[[ $HOST == "disco" ]] && export MACHINE="spectre"
! [[ -v MACHINE ]] && export MACHINE="fjerde"


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

# Pacman specific
alias pacupgrade="sudo pacman -Syyu"
alias pacsearch="sudo pacman -Ss"
alias pacinstall="sudo pacman -S"
alias pacclean='sudo paccache -r && sudo pacman -Qtdq | sudo pacman -Rns -'

alias ssh_insecure="ssh -oKexAlgorithms=+diffie-hellman-group1-sha1"
alias dc="cd"
alias vpn="sudo openconnect -bq --user=$USER vpn.ntnu.no"
alias random="tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''"
alias gencert="sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.crt"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Add completion to custom pdf command
zstyle ':completion:*:*:pdf:*' file-patterns '*.pdf'
zstyle ':completion:*:*:(nvim|vim):*' ignored-patterns '*.pdf'

export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/nvim

# Betterman tm
man(){
    command man $1 || $_ --help
}

# This doesnt work all the time
wifi_pass(){
    sudo grep -oP '^psk=\K\w+' /etc/NetworkManager/system-connections/$(nmcli -t -f name connection show --active | head -n1).nmconnection
}

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin"
[ -f "/home/theodorc/.ghcup/env" ] && source "/home/theodorc/.ghcup/env" # ghcup-env

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
source /usr/share/nvm/init-nvm.sh
