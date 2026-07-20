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

srcenv() {
  local envfile=".env"

  if [[ "$1" == "-e" ]]; then
    if [[ -z "$2" ]]; then
      print -u2 "usage: srcenv [-e envfile] command [args...]"
      return 2
    fi

    envfile="$2"
    shift 2
  fi

  if [[ $# -eq 0 ]]; then
    print -u2 "usage: srcenv [-e envfile] command [args...]"
    return 2
  fi

  if [[ ! -f "$envfile" ]]; then
    print -u2 "srcenv: env file not found: $envfile"
    return 1
  fi

  (
    set -a
    source "$envfile" || return 1
    set +a
    command "$@"
  )
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

dirty() {
    local root="${1:-.}"
    find "$root" -name ".git" -type d -prune | while read gitdir; do
        local repo="${gitdir%/.git}"
        if ! git -C "$repo" diff --quiet 2>/dev/null || \
           ! git -C "$repo" diff --cached --quiet 2>/dev/null || \
           [[ -n $(git -C "$repo" ls-files --others --exclude-standard 2>/dev/null) ]]; then
            echo "$repo"
        fi
    done
}

# Claude Code launcher: resume or create a named session
# Usage:
#   cc              → auto-name from dir+branch, resume or create
#   cc enter        → same as above
#   cc -n <name>    → resume or create session with given name
#   cc <other args> → pass through to claude
cc() {
    local session_name

    if [[ $# -eq 0 ]] || [[ "$1" == "enter" ]]; then
        local dir branch
        dir=$(basename "$PWD")
        branch=$(git branch --show-current 2>/dev/null)
        session_name="${dir}${branch:+-${branch}}"
    elif [[ "$1" == "-n" ]] && [[ -n "$2" ]]; then
        session_name="$2"
    else
        command claude "$@"
        return
    fi

    local session_id
    session_id=$(python3 - "$session_name" <<'EOF'
import json, pathlib, sys
name = sys.argv[1]
p = pathlib.Path.home() / '.claude/projects'
matches = []
for f in p.glob('**/*.jsonl'):
    try:
        for line in f.read_text().splitlines():
            d = json.loads(line)
            if d.get('type') == 'custom-title' and d.get('customTitle') == name:
                matches.append((f.stat().st_mtime, d['sessionId']))
                break
    except:
        pass
if matches:
    matches.sort(reverse=True)
    print(matches[0][1])
EOF
    )

    if [[ -n "$session_id" ]]; then
        echo "Resuming: $session_name"
        command claude --resume "$session_id"
    else
        echo "New session: $session_name"
        command claude -n "$session_name"
    fi
}

