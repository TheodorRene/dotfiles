# Path to your oh-my-zsh installation.
zmodload zsh/zprof
export ZSH="$HOME/.oh-my-zsh"
zstyle ':completion:*' rehash true


path+=$HOME/.local/bin
path+=$HOME/.dotnet
path+=$HOME/.cargo/bin
path+=$HOME/.local/share/bob/nvim-bin
path+=$HOME/.luarocks/bin
path+=$HOME/.npm-packages/bin
path+=./node_modules/.bin
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/emulator
export JAVA_HOME="/Users/thca/.openjdk/jdk-17/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

NPM_PACKAGES="${HOME}/.npm-packages"
export XDG_CONFIG_HOME=$HOME/.config

# Preserve MANPATH if you already defined it somewhere in your config.
# Otherwise, fall back to `manpath` so we can inherit from `/etc/manpath`.
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
alias mosh="export LC_ALL=\"en_US.UTF8\" && mosh"

export MANPAGER='nvim +Man!'

# github copilot cli x
# eval "$(github-copilot-cli alias -- "$0")"
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="theodorc"

mango(){
    $@ | lolcat
}


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

fd(){
  bfs -name "*$1*" 
}

alias ls="eza"
alias bc="bc -lq"
#alias c="code . && exit" So long and thanks for all the fish
alias cal="ncal -3wb"
alias cass="mosh cassarossa.samfundet.no"
alias cat="bat"
alias clip="pbcopy"
alias clipboard2file='xclip -selection clipboard -t image/png -o > "$(date +%Y-%m-%d_%T).png"'
alias deadkeys='setxkbmap -layout no -variant nodeadkeys -option ctrl:nocaps'
alias dir="ls -d */"
alias dig="dig +noall +answer"
alias dsize="du -h --max-depth=1 | sort -h"
alias gs="git status" #So many misstyping and fk ghostscript
alias locate="plocate"
alias lr="eza -lrhF -snew" 
#alias lr="ls -lrthF"
alias lra="ls -ltrha"
alias lsblk="lsblk -f"
alias lzd="lazydocker"
alias numdate="date +%s"
alias ports="sudo lsof -i -P -n | grep LISTEN"
alias py="python"
alias python="python3"
alias reminder="vim ~/dev/reminder_for_tomorrow.md"
alias rg="rg -i"
alias ag="rg -i"
alias setbackground="feh --bg-scale"
alias shut="shutdown now"
alias start="tmuxinator start project ts-frontend"
alias sugit="sudo -E git"
alias suvim="sudo -E vim"
alias svenv="source venv/bin/activate"
alias sys="systemctl"
alias t="tmux new-session -A -s main"
alias takeover="tmux detach -a"
alias english2norsk="trans -s en -t nb"
alias norsk2english="trans -s nb -t en"
alias norsk2dansk="trans -s nb -t da"
alias ukenr="date +%V"
alias uuid="uuidgen | clip; echo 'UUID copied'"
alias vim="nvim"
alias vimnote="vim $(date +"%m_%d_%Y").md"
alias wclip="wl-copy"

alias blank="autorandr blank"
alias nrd="npm run dev"
alias nrt="npm run test"
alias nrs="npm run start"
alias nrp="npm run start:prod"
alias ni="npm install"



# ANDROID
alias shake="adb shell input keyevent 82"
alias logcat="adb logcat"
alias run_android="/Users/thca/Library/Android/sdk/emulator/emulator -avd Pixel_7_API_34"
alias run_tablet="/Users/thca/Library/Android/sdk/emulator/emulator -avd Pixel_Tablet_API_34"
alias run_android_ipad="/Users/thca/Library/Android/sdk/emulator/emulator -avd Ipad_10th_Generation_API_34"

#iPad (10th generation) (E5AD111D-2FF1-4D56-9FE1-FE5904D9194C)
alias run_ipad="xcrun simctl boot 'iPad (10th generation)'"
#iPhone 15 (7B2D6F3D-168B-463A-AF5D-AE6D2735572D)
alias run_iphone="xcrun simctl boot 'iPhone 15'"

nuke_containers() {docker rm -f $(docker ps -a -q)}
nuke_everything() {nuke_containers && nuke_images && nuke_volumes && echo "Nuked everything"}
nuke_images() {docker rmi $(docker images -aq) && echo "Images nuked"}
nuke_volumes() {docker volume rm $(docker volume ls -q)}
# start shell
shell() {docker exec -it $1 bash}
run() { docker run --rm -it $1 /bin/sh }

# run single command
cmd() {docker exec -it $1 ${@:2}}

# copy the command to clipboard
copy() { echo "$@"| pbcopy }

minpdf() {
    ls -hl $1 && command gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=minified_$1 $1 && echo "zipped pdf" && ls -hl minified_$1
}

b64d(){
    echo $1 | base64 -d
}

b64e(){
    echo $1 | base64 
}


alias universallink="xcrun simctl openurl booted"
alias applink="adb shell am start -W -a android.intent.action.VIEW -d"
# open links in iphone or android

# Pacman specific
alias pacclean='sudo paccache -r && sudo pacman -Qtdq | sudo pacman -Rns -'
alias pacinstall="sudo pacman -S"
alias pacremove="sudo pacman -R"
alias pacsearch="sudo pacman -Ss"

alias aptclean='echo ">sudo apt autoremove && sudo apt clean" && sudo apt autoremove && sudo apt clean'
alias aptinstall="sudo apt install"
alias aptremove="sudo apt uninstall"
alias aptsearch="apt search"
alias aptupgrade="sudo apt update && apt list --upgradable && sudo apt upgrade"

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
        if read -q "choice?Use Neovim session file? Y/y:"; then
            nvim -S Session.vim
        else
            echo "\nMoving session file to desktop..."
            sleep 1
            mv Session.vim ~/Desktop/OldSession.vim
            nvim
        fi
    else
        nvim
    fi
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Add completion to custom pdf command
zstyle ':completion:*:*:pdf:*' file-patterns '*.pdf'
zstyle ':completion:*:*:(nvim|vim):*' ignored-patterns '*.pdf'

export EDITOR=$(which nvim)
export VISUAL=$(which nvim)

# Betterman tm
man(){
    command man $1 || $_ --help
}

# if no arguments are given, show usage
# if first argument is equal "devices" run 'xcrun xctrace list devices'
ios(){
    if [ $# -eq 0 ]; then
        echo "Usage: ios devices"
    elif [ $1 = "devices" ]; then
        xcrun xctrace list devices
    else
        echo "Usage: ios devices"
        exit 1
    fi
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


# bun completions
[ -s "/home/theodorc/.bun/_bun" ] && source "/home/theodorc/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
eval "$(direnv hook zsh)"

#defaults write -g NSWindowShouldDragOnGesture YES

# flashlight
export PATH="/Users/thca/.flashlight/bin:$PATH"
. "/Users/thca/.deno/env"
eval "$(gh copilot alias -- zsh)"
zprof

[ -f "/Users/thca/.ghcup/env" ] && . "/Users/thca/.ghcup/env" # ghcup-env
