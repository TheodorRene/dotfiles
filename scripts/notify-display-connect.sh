#!/usr/bin/env bash
# Notify (mako) whenever a display connector changes state.
#
# Exists because DP on the non-Thunderbolt USB-C port can take ~10s to come up,
# and the monitor is still dark while you are deciding whether to give up and
# replug. The notification lands on the laptop panel, which is already awake.
#
# Run standalone, or via systemd/user/display-notify.service.

poll="${POLL_INTERVAL:-1}"
notify_urgency="${NOTIFY_URGENCY:-normal}"
notify_timeout="${NOTIFY_TIMEOUT:-0}"          # 0 = stay until clicked
icon=/usr/share/icons/Adwaita/scalable/devices/video-display.svg
[ -r "$icon" ] || icon=video-display

state_of() {
  local c
  for c in /sys/class/drm/card*-*; do
    [ -e "$c/status" ] || continue
    printf '%s=%s\n' "${c##*/}" "$(cat "$c/status" 2>/dev/null)"
  done
}

# Human name + mode for a connector, best effort. sway knows the model; sysfs
# alone only knows the connector.
describe() {
  local conn="$1" out
  out="${conn#card*-}"                       # card1-DP-1 -> DP-1
  if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local d
    d=$(swaymsg -t get_outputs 2>/dev/null | jq -r --arg o "$out" '
      .[] | select(.name==$o) |
      "\(.make) \(.model) \(.current_mode.width)x\(.current_mode.height)@\((.current_mode.refresh/1000)|floor)Hz"' 2>/dev/null)
    [ -n "$d" ] && [ "$d" != "null" ] && { printf '%s — %s' "$out" "$d"; return; }
  fi
  printf '%s' "$out"
}

# Seconds since this port's DP alt mode went active, if we can tell. This is the
# number that makes the ~10s wait legible instead of feeling random.
altmode_age() {
  local a newest=0 t
  for a in /sys/class/typec/*-partner/*.[0-9]; do
    [ -d "$a" ] || continue
    [ "$(cat "$a/svid" 2>/dev/null)" = "ff01" ] || continue
    t=$(stat -c %Y "$a" 2>/dev/null) || continue
    [ "$t" -gt "$newest" ] && newest=$t
  done
  [ "$newest" -gt 0 ] && echo $(( $(date +%s) - newest ))
}

prev="$(state_of)"
while true; do
  sleep "$poll"
  cur="$(state_of)"
  [ "$cur" = "$prev" ] && continue

  while IFS= read -r line; do
    conn="${line%%=*}"; now="${line#*=}"
    was=$(printf '%s\n' "$prev" | grep "^$conn=" | cut -d= -f2)
    [ "$now" = "$was" ] && continue
    case "$conn" in *eDP*) continue ;; esac   # internal panel, not interesting

    if [ "$now" = connected ]; then
      age=$(altmode_age)
      body="$(describe "$conn")"
      [ -n "$age" ] && body="$body"$'\n'"came up ${age}s after alt mode went active"
      notify-send -u "$notify_urgency" -t "$notify_timeout" -i "$icon" "Display connected" "$body"
      printf '\a'
      echo "$(date +%T) CONNECTED $conn ${age:+(+${age}s)}"
    elif [ "$now" = disconnected ]; then
      notify-send -u low -i "$icon" "Display disconnected" "${conn#card*-}"
      echo "$(date +%T) DISCONNECTED $conn"
    fi
  done <<< "$cur"

  prev="$cur"
done
