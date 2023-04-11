# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
path+=$HOME/.local/bin
path+=/var/lib/snapd/snap/bin
path+=$HOME/.cargo/bin
path+=$HOME/.luarocks/bin

export MANPAGER='nvim +Man!'

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME2="~/dotfiles/theodorc.zsh-theme"
ZSH_THEME="theodorc"

mango(){
    $@ | lolcat
}


#Plugins
plugins=(
    autojump
    docker
    extract
    fzf
    git
    last-working-dir
    sudo
    zsh-aws-vault
    kubectl
)
DISABLE_MAGIC_FUNCTIONS=true
source $ZSH/oh-my-zsh.sh
~/bin/run_tmux_if_vim

alias bc="bc -lq"
#alias c="code . && exit" So long and thanks for all the fish
alias cal="ncal -3wb"
alias cass="mosh cassarossa.samfundet.no"
alias cat="bat"
alias clip="xclip -selection c"
alias clipboard2file='xclip -selection clipboard -t image/png -o > "$(date +%Y-%m-%d_%T).png"'
alias dir="ls -d */"
alias dsize="du -h --max-depth=1 | sort -h"
alias gs="git status" #So many misstyping and fk ghostscript
alias locate="plocate"
alias lr="ls -ltrh"
alias lsblk="lsblk -f"
alias lzd="lazydocker"
alias ports="sudo lsof -i -P -n | grep LISTEN"
alias py="python"
alias python="python3"
alias rg="rg -i"
alias shut="shutdown now"
alias start="tmuxinator start project ts-frontend"
alias sugit="sudo -E git"
alias suvim="sudo -E vim"
alias svenv="source venv/bin/activate"
alias sys="systemctl"
alias t="tmux new-session -A -s main"
alias takeover="tmux detach -a"
alias te="trans -s en -t nb"
alias tn="trans -s nb -t en"
alias ukenr="date +%V"
alias uuid="uuidgen | wl-copy; echo 'UUID copied'"
alias vim="nvim"
alias vimnote="vim $(date +"%m_%d_%Y").md"
alias wclip="wl-copy"

# FOLQ
alias blank="autorandr blank"
alias cv="chromium http://localhost:3420/cv/debug &!"
alias folq="autorandr folq"
alias getenv="cp -i $HOME/dev/blank/folq_web/ts-frontend/.env . && echo 'Copied env file'"
alias localdb="pgcli -h localhost -U folq"
alias nrd="npm run dev"
alias nrs="npm run storybook"
alias nrt="npm run tsc"
alias profil="chromium http://localhost:3420/debug &!"
alias refolqdb="docker start folqdb && docker restart hasura-graphql-engine-1"




nuke_containers() {docker rm -f $(docker ps -a -q)}
nuke_everything() {nuke_containers && nuke_images && nuke_volumes && echo "Nuked everything"}
nuke_images() {docker rmi $(docker images -aq) && echo "Images nuked"}
nuke_volumes() {docker volume rm $(docker volume ls -q)}
# start shell
shell() {docker exec -it $1 bash}

# run single command
cmd() {docker exec -it $1 ${@:2}}

minpdf() {
ls -hl $1 && command gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=minified_$1 $1 && echo "zipped pdf" && ls -hl minified_$1
}

b64d(){
    echo $1 | base64 -d
}

b64e(){
    echo $1 | base64 
}


# Pacman specific
alias pacclean='sudo paccache -r && sudo pacman -Qtdq | sudo pacman -Rns -'
alias pacinstall="sudo pacman -S"
alias pacremove="sudo pacman -R"
alias pacsearch="sudo pacman -Ss"

alias aptclean='echo ">sudo apt autoremove && sudo apt clean" && sudo apt autoremove && sudo apt clean'
alias aptinstall="sudo apt install"
alias aptremove="sudo apt uninstall"
alias aptsearch="apt search"
alias aptupgrade="sudo apt update && sudo apt upgrade"

alias dc="cd"
alias gencert="sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout selfsigned.key -out selfsigned.crt"
alias ipp="curl -s ip.xxd.no"
alias random="tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo ''"
alias server="python -m http.server 8000"
alias ssh_insecure="ssh -oKexAlgorithms=+diffie-hellman-group1-sha1"
alias vpn="sudo openconnect -bq --user=$USER vpn.ntnu.no"

# alias work="sleep $((60*20)) && aplay /usr/share/sounds/speech-dispatcher/test.wav &&  notify-send -t 5000 -u critical '5 minutter pause'"
# alias break="sleep $((60*5)) && aplay /usr/share/sounds/speech-dispatcher/test.wav &&  notify-send -t 5000 -u critical '5 minutter pause'"
#alias v="vim"


# check if a file with the name of 'Session.vim' exists in the current directory
# if it does, then use it as the session file with nvim
v(){
    if [ -f "Session.vim" ]; then
        nvim -S Session.vim
    else
        nvim
    fi
}

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
    sudo grep -oP '^psk=\K\w+.*' /etc/NetworkManager/system-connections/$(nmcli -t -f name connection show --active | head -n1).nmconnection
}

mnt(){
    sudo mount $1 /mnt/usb && cd /mnt/usb && ls
}

umnt(){
    sudo umount /mnt/usb && echo "Unmounted successfully"
}

pass() {
    bw get password $1 | xclip -selection c && "Password copied"
}
tsv() {
    column -s$'\t' -t < $1 | less -N -S
}
load_dotenv() { 
    echo "dotenv" > .envrc; direnv allow 
}

# Conditionally open less based on size of input
# I like having small git diffs not in a pager
export LESS="-RFX"

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin:$HOME/bin"

[ -f "/home/theodorc/.ghcup/env" ] && source "/home/theodorc/.ghcup/env" # ghcup-env

# bun completions
[ -s "/home/theodorc/.bun/_bun" ] && source "/home/theodorc/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
eval "$(direnv hook zsh)"

