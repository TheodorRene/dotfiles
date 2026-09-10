#!/usr/bin/env bash
# Toggle mute / adjust gain on the default audio source and show a mako popup.
# Bound to XF86AudioMicMute (sway/config) and to the waybar mic module.
# Usage: mic.sh up|down|mute
set -euo pipefail

SOURCE="@DEFAULT_AUDIO_SOURCE@"

case "${1:-}" in
  up)   wpctl set-volume -l 1.0 "$SOURCE" 5%+ ;;
  down) wpctl set-volume "$SOURCE" 5%- ;;
  mute) wpctl set-mute "$SOURCE" toggle ;;
esac

state="$(wpctl get-volume "$SOURCE")"             # "Volume: 0.85" or "Volume: 0.85 [MUTED]"
perc="$(awk '{printf "%d", $2 * 100}' <<<"$state")"

# Which mic this actually is — the Anker C200 steals the default source when
# plugged in, so naming it is the point of the popup.
name="$(wpctl inspect "$SOURCE" 2>/dev/null \
        | sed -n 's/^[ *]*node\.description *= *"\(.*\)"$/\1/p' | head -1)"
name="${name:-default source}"

# synchronous hint => repeated presses replace the same popup; value hint => progress bar
if [[ "$state" == *MUTED* ]]; then
  notify-send -t 1200 -h string:x-canonical-private-synchronous:mic \
    -h int:value:0 " Mic muted" "$name"
else
  notify-send -t 1200 -h string:x-canonical-private-synchronous:mic \
    -h int:value:"$perc" " Mic live" "$name — ${perc}%"
fi
