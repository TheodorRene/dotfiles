#!/usr/bin/env bash
# Adjust backlight and show a mako progress popup. Usage: brightness-wayland.sh up|down
set -euo pipefail

case "${1:-}" in
  up)   brightnessctl -q set 5%+ ;;
  down) brightnessctl -q set 5%- ;;
esac

perc="$(brightnessctl -m | awk -F, '{gsub("%","",$4); print $4}')"

# synchronous hint => repeated presses replace the same popup; value hint => progress bar
notify-send -t 1200 -h string:x-canonical-private-synchronous:brightness \
  -h int:value:"$perc" "🔆 Brightness" "${perc}%"
