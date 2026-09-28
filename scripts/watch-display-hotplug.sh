#!/usr/bin/env bash
# Continuously log USB-C alt-mode + DRM connector state across a hotplug test.
# Start it BEFORE unplugging, leave it running, Ctrl-C when done.
#
#   ~/dotfiles/scripts/watch-display-hotplug.sh
#
# Logs to /var/tmp (NOT /tmp, which is tmpfs here) so the trace survives a
# compositor crash or reboot.

log="${1:-/var/tmp/display-hotplug-$(date +%Y%m%d-%H%M%S).log}"

say() { printf "%s %s\n" "$(date "+%T.%N" | cut -c1-12)" "$*" >> "$log"; }

snapshot() {
  local tag="$1" s=""
  for c in /sys/class/drm/card*-DP-*; do
    [ -e "$c/status" ] && s+="$(basename "$c")=$(cat "$c/status") "
  done
  local am=""
  for a in /sys/class/typec/*-partner/*.[0-9]; do
    [ -d "$a" ] || continue
    am+="$(basename "$(dirname "$a")")/svid=$(cat "$a/svid" 2>/dev/null)"
    am+=",active=$(cat "$a/active" 2>/dev/null),vdo=$(cat "$a/vdo" 2>/dev/null) "
  done
  [ -z "$am" ] && am="(no partner altmodes)"
  say "[$tag] DRM: $s"
  say "[$tag] PARTNER: $am"
}

{
  echo "=== display hotplug trace, started $(date -Is) ==="
  echo "kernel: $(uname -r)   BIOS: $(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
  echo
} > "$log"

snapshot initial

# Kernel messages, live.
journalctl -k -f -n0 --no-pager 2>/dev/null \
  | grep --line-buffered -iE "ucsi|typec|drm|xe |hpd|link training|usb .*(new|disconnect)" \
  | while IFS= read -r l; do say "KERNEL $l"; done &
jpid=$!

# Kernel uevents for drm + typec. Unprivileged: kernel-level, no root needed.
udevadm monitor --kernel --subsystem-match=drm --subsystem-match=typec 2>/dev/null \
  | while IFS= read -r l; do [ -n "$l" ] && say "UEVENT $l"; done &
upid=$!

trap 'kill $jpid $upid 2>/dev/null; snapshot final; echo; echo "trace written to $log"; exit 0' INT TERM

echo "Tracing -> $log"
echo "Now: unplug the dongle, wait ~5s, plug into the OTHER port, wait ~15s."
echo "Repeat a few times (the fault is intermittent). Ctrl-C when done."
echo
echo "IMPORTANT: do NOT press F9 during this test - that is what segfaulted"
echo "sway this morning (toggle-display.sh racing the unplug teardown)."

# Poll state twice a second so we catch transitions the logs don't mention.
prev=""
hit=no
while true; do
  cur=""
  for c in /sys/class/drm/card*-DP-*; do
    [ -e "$c/status" ] && cur+="$(basename "$c")=$(cat "$c/status") "
  done
  for a in /sys/class/typec/*-partner/*.[0-9]; do
    [ -d "$a" ] && cur+="$(basename "$(dirname "$a")")/$(cat "$a/svid" 2>/dev/null):$(cat "$a/active" 2>/dev/null) "
  done
  if [ "$cur" != "$prev" ]; then
    say "CHANGE $cur"
    # Shout when a DP connector actually comes up - the trial we care about.
    case "$cur" in
      *DP-[0-9]=connected*)
        if [ "$hit" != yes ]; then
          hit=yes
          say "*** SUCCESS: a DP connector went connected ***"
          notify-send -u critical "Display debug" "SUCCESS - DP came up" 2>/dev/null
          printf '\a'
          echo "*** SUCCESS at $(date +%T) - DP connector came up. Ctrl-C to stop. ***"
        fi
        ;;
      *) hit=no ;;
    esac
    prev="$cur"
  fi
  sleep 0.5
done
