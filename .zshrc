# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
path+=$HOME/.local/bin
path+=/var/lib/snapd/snap/bin

export MANPAGER='nvim +Man!'

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME2="~/dotfiles/theodorc.zsh-theme"
ZSH_THEME="theodorc"

# If you want to do machine specific config
[[ $HOST == "abba" ]] && export MACHINE="desktop"
[[ $HOST == "disco" ]] && export MACHINE="spectre"
! [[ -v MACHINE ]] && export MACHINE="fjerde"

mango(){
    $@ | lolcat
}


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
    autojump
)

source $ZSH/oh-my-zsh.sh

alias takeover="tmux detach -a"
alias ls="lsd"
alias lr="ls -ltrh"
alias cass="mosh cassarossa.samfundet.no"
alias shut="shutdown now"
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
alias locate="plocate"
alias lsblk="lsblk -f"
alias rg="rg -i"

nuke_containers() {docker rm -f $(docker ps -a -q)}

nuke_volumes() {docker volume rm $(docker volume ls -q)}

nuke_images() {docker rmi $(docker images -aq)}

# Pacman specific
alias pacupgrade="sudo pacman -Syyu"
alias pacsearch="sudo pacman -Ss"
alias pacinstall="sudo pacman -S"
alias pacremove="sudo pacman -R"
alias pacclean='sudo paccache -r && sudo pacman -Qtdq | sudo pacman -Rns -'

alias ipp="curl -w "\n" ifconfig.me"
alias ssh_insecure="ssh -oKexAlgorithms=+diffie-hellman-group1-sha1"
alias dc="cd"
alias vpn="sudo openconnect -bq --user=$USER vpn.ntnu.no"
alias random="tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''"
alias gencert="sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.crt"
alias work="sleep $((60*20)) && aplay /usr/share/sounds/speech-dispatcher/test.wav &&  notify-send -t 5000 -u critical '5 minutter pause'"
alias break="sleep $((60*5)) && aplay /usr/share/sounds/speech-dispatcher/test.wav &&  notify-send -t 5000 -u critical '5 minutter pause'"

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

#make grep work like rg and ag
tgrep(){
    command grep -RIin --color=auto --exclude-dir={.git,venv,node_modules} $1 *
}

pdfgrep(){
    command pdfgrep -i $1 *
}

# This doesnt work all the time
wifi_pass(){
    sudo grep -oP '^psk=\K\w+' /etc/NetworkManager/system-connections/$(nmcli -t -f name connection show --active | head -n1).nmconnection
}

mnt(){
    sudo mount $1 /mnt/usb && cd /mnt/usb && ls
}

umnt(){
    sudo umount /mnt/usb
}

pass() {
    bw get password $1 | xclip -selection c
    echo "Password copied"
}

# Conditionally open less based on size of input
# I like having small git diffs not in a pager
export LESS="-RFX"

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin:$HOME/bin"
[ -f "/home/theodorc/.ghcup/env" ] && source "/home/theodorc/.ghcup/env" # ghcup-env

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#source /usr/share/nvm/init-nvm.sh
#. '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
