#!/usr/bin/env bash
# Claude Code hook handler: desktop notifications, plus flash the terminal
# (sway urgent) and a clickable toast that focuses it when input is needed.
# Usage: claude-attention.sh waiting|idle   (Notification message on stdin for 'waiting')
set -uo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"

# Pidfile tracking the current toast for a given sway container.
pidfile_for() { printf '%s/claude-attention-con-%s.pid' "$runtime_dir" "$1"; }

# Supersede the toast still open for a container: kill the detached __click
# process group (which includes its blocking `notify-send --wait`) so toasts
# don't accumulate one-per-event. Guarded by a cmdline check so a recycled PID
# can't make us kill an unrelated process group.
kill_toast() {
  local con="$1" pf pg
  pf="$(pidfile_for "$con")"
  [ -f "$pf" ] || return 0
  pg="$(cat "$pf" 2>/dev/null || true)"
  if [ -n "$pg" ] && grep -qa 'claude-attention' "/proc/$pg/cmdline" 2>/dev/null; then
    kill -- "-$pg" 2>/dev/null || true
  fi
  rm -f "$pf"
}

# Detached click-handler: clickable toast that focuses the terminal.
# `notify-send --wait` blocks until the toast is actioned or closed. The caller
# runs us via `setsid -f`, so $$ is our session/process-group leader; we register
# it in a pidfile so the next attention event (or `idle`) can supersede us
# instead of leaving a blocked notify-send behind.
if [ "${1:-}" = "__click" ]; then
  con="$2"; msg="$3"
  kill_toast "$con"                       # replace any previous toast for this con
  echo "$$" > "$(pidfile_for "$con")"     # $$ == our PGID (session leader via setsid -f)
  action="$(notify-send --wait -A default=Focus -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true)"
  pf="$(pidfile_for "$con")"
  [ "$(cat "$pf" 2>/dev/null || true)" = "$$" ] && rm -f "$pf"   # clean up if still ours
  [ -n "$action" ] && swaymsg "[con_id=$con] focus" >/dev/null 2>&1
  exit 0
fi

state="${1:-idle}"

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

case "$state" in
  waiting)
    msg="$(jq -r '.message // empty' 2>/dev/null || true)"; msg="${msg:-Needs your input}"
    con="$(find_con)"
    if [ -n "${con:-}" ]; then
      swaymsg "[con_id=$con] urgent enable" >/dev/null 2>&1 || true       # flash the workspace red
      setsid -f "$0" __click "$con" "$msg" >/dev/null 2>&1 || true        # clickable toast (detached)
    else
      notify-send -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true
    fi
    ;;
  idle)
    con="$(find_con)"
    [ -n "${con:-}" ] && kill_toast "$con"     # clear any pending toast now that we're done
    notify-send -u normal -t 4000 "🤖 Claude Code" "✅ Done — finished working" 2>/dev/null || true
    ;;
esac
exit 0
