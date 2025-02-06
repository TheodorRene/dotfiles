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
