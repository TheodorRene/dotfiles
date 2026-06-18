#!/usr/bin/env bash
# Claude Code hook handler: track state for the waybar module, and on "waiting"
# flash the terminal (sway urgent) + send a clickable toast that focuses it.
# Usage: claude-attention.sh working|waiting|idle   (Notification message on stdin)
set -uo pipefail

runtime="${XDG_RUNTIME_DIR:-/tmp}"

# Detached click-handler: wait for the toast action, focus the terminal on click.
if [ "${1:-}" = "__click" ]; then
  con="$2"; msg="$3"
  action="$(notify-send --wait -A default=Focus -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true)"
  [ -n "$action" ] && swaymsg "[con_id=$con] focus" >/dev/null 2>&1
  exit 0
fi

state="${1:-idle}"
printf '%s' "$state" > "$runtime/claude-waybar-state"
pkill -RTMIN+8 -x waybar 2>/dev/null || true   # refresh the custom/claude module

# Find the sway container running this Claude: walk our ancestor PIDs, match the tree.
find_con() {
  local p="$PPID" pids=""
  while [ "${p:-0}" -gt 1 ]; do
    pids+="$p "
    p="$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)" || break
  done
  swaymsg -t get_tree 2>/dev/null | jq -r --arg pids "$pids" '
    [recurse(.nodes[]?, .floating_nodes[]?) | select(.pid != null)]
    | map(select(.pid as $pp | ($pids | split(" ") | map(select(length>0) | tonumber)) | index($pp)))
    | (.[0].id // empty)'
}

# Record this Claude's window id on every state so clicking the module always focuses it.
con="$(find_con)"
printf '%s' "${con:-}" > "$runtime/claude-waybar-con"

case "$state" in
  waiting)
    msg="$(jq -r '.message // empty' 2>/dev/null || true)"; msg="${msg:-Needs your input}"
    if [ -n "${con:-}" ]; then
      swaymsg "[con_id=$con] urgent enable" >/dev/null 2>&1 || true
      setsid -f "$0" __click "$con" "$msg" >/dev/null 2>&1 || true
    else
      notify-send -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true
    fi
    ;;
  idle)
    notify-send -u normal -t 4000 "🤖 Claude Code" "✅ Done — finished working" 2>/dev/null || true
    ;;
esac
exit 0
