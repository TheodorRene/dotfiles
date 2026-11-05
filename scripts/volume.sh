#!/usr/bin/env bash
# Adjust volume / toggle mute and show a mako progress popup.
# Usage: volume.sh up|down|mute
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"

# While the jack EQ (scripts/eq.sh) is the default output, keep the keys on the
# jack's own hardware volume; the EQ sink itself stays at 100%. Inert otherwise:
# the file only exists while the EQ is on.
eq_jack="${XDG_RUNTIME_DIR:-/run/user/$UID}/jack-eq/jack-id"
if [[ -r $eq_jack ]] && wpctl inspect "$SINK" 2>/dev/null | grep -q 'node\.name = "jack_eq"'; then
  SINK="$(<"$eq_jack")"
fi

case "${1:-}" in
  up)   wpctl set-volume -l 1.0 "$SINK" 5%+ ;;
  down) wpctl set-volume "$SINK" 5%- ;;
  mute) wpctl set-mute "$SINK" toggle ;;
esac

state="$(wpctl get-volume "$SINK")"               # "Volume: 0.38" or "Volume: 0.38 [MUTED]"
perc="$(awk '{printf "%d", $2 * 100}' <<<"$state")"

# synchronous hint => repeated presses replace the same popup; value hint => progress bar
if [[ "$state" == *MUTED* ]]; then
  notify-send -t 1200 -h string:x-canonical-private-synchronous:volume \
    -h int:value:0 "🔇 Volume" "Muted"
else
  notify-send -t 1200 -h string:x-canonical-private-synchronous:volume \
    -h int:value:"$perc" "🔊 Volume" "${perc}%"
fi
