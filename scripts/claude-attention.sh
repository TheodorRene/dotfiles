#!/usr/bin/env bash
# Claude Code hook handler: desktop notifications, plus flash the terminal
# (sway urgent) and a clickable toast that focuses it when input is needed.
# Usage: claude-attention.sh waiting|idle   (Notification message on stdin for 'waiting')
#
# Under herdr, claude runs under the herdr *server*, not the terminal, so the
# window is found via the attached herdr *client* instead, and one window hosts
# every session: toasts are keyed per herdr pane, and clicking one also switches
# herdr to that session's tab.
set -uo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"

# Pidfile tracking the current toast for one session: the herdr pane if there is
# one (several sessions share a window), else the sway container.
pidfile_for() { printf '%s/claude-attention-%s.pid' "$runtime_dir" "${1//[^A-Za-z0-9_.-]/_}"; }
toast_key() { if [ -n "${HERDR_PANE_ID:-}" ]; then echo "herdr-$HERDR_PANE_ID"; else echo "con-$1"; fi; }

# Supersede the toast still open for a container: kill the detached __click
# process group (which includes its blocking `notify-send --wait`) so toasts
# don't accumulate one-per-event. Guarded by a cmdline check so a recycled PID
# can't make us kill an unrelated process group.
kill_toast() {
  local key="$1" pf pg
  pf="$(pidfile_for "$key")"
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
  key="$2"; con="$3"; msg="$4"
  kill_toast "$key"                       # replace any previous toast for this session
  echo "$$" > "$(pidfile_for "$key")"     # $$ == our PGID (session leader via setsid -f)
  action="$(notify-send --wait -A default=Focus -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true)"
  pf="$(pidfile_for "$key")"
  [ "$(cat "$pf" 2>/dev/null || true)" = "$$" ] && rm -f "$pf"   # clean up if still ours
  if [ -n "$action" ]; then
    [ -n "${HERDR_TAB_ID:-}" ] && herdr tab focus "$HERDR_TAB_ID" >/dev/null 2>&1
    swaymsg "[con_id=$con] focus" >/dev/null 2>&1
  fi
  exit 0
fi

state="${1:-idle}"

# Herdr session label for toasts ("tab label" or empty outside herdr).
herdr_label() {
  [ -n "${HERDR_TAB_ID:-}" ] || return 0
  herdr tab get "$HERDR_TAB_ID" 2>/dev/null | jq -r '.result.tab.label // empty' 2>/dev/null
}

# The sway window showing this Claude (herdr-aware); the lookup lives in swayq.
find_con() { "$(dirname "$(readlink -f "$0")")/swayq" whereami --con 2>/dev/null; }

case "$state" in
  waiting)
    msg="$(jq -r '.message // empty' 2>/dev/null || true)"; msg="${msg:-Needs your input}"
    label="$(herdr_label)"; [ -n "$label" ] && msg="[$label] $msg"
    con="$(find_con)"
    if [ -n "${con:-}" ]; then
      swaymsg "[con_id=$con] urgent enable" >/dev/null 2>&1 || true       # flash the workspace red
      setsid -f "$0" __click "$(toast_key "$con")" "$con" "$msg" >/dev/null 2>&1 || true  # clickable toast (detached)
    else
      notify-send -u normal "🤖 Claude Code" "$msg" 2>/dev/null || true
    fi
    ;;
  idle)
    con="$(find_con)"
    [ -n "${con:-}" ] && kill_toast "$(toast_key "$con")"   # clear this session's pending toast
    label="$(herdr_label)"
    notify-send -u normal -t 4000 "🤖 Claude Code" "✅ Done${label:+ — $label}" 2>/dev/null || true
    ;;
esac
exit 0
