mango(){
    $@ | lolcat
}

fd(){
  bfs -name "*$1*" 
}

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

