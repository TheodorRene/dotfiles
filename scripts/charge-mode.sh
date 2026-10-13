#!/usr/bin/env bash
# Toggle how the battery charges.
#
#   park    - don't charge at all (Custom 50/55). Use when the monitor's USB-C
#             cable is what's powering the laptop: the charge current is what
#             makes that link drop. The laptop still runs off the cable, the
#             battery just sits there.
#   normal  - charge properly (Fast 50/90), the factory setting. Use on a
#             separate charger, or with no monitor attached.
#
# Usage:  charge-mode.sh [toggle|park|normal|status]     (default: toggle)
#
# See docs/usb-c-displays-disconnect-and-kernel-options.md.
set -euo pipefail

BAT=/sys/class/power_supply/BAT0

show() {
  local t s e
  t=$(grep -o '\[[A-Za-z]*\]' "$BAT/charge_types" | tr -d '[]')
  s=$(cat "$BAT/charge_control_start_threshold")
  e=$(cat "$BAT/charge_control_end_threshold")
  printf '%s %s/%s  |  %s %s%%  %.1f W\n' \
    "$t" "$s" "$e" \
    "$(cat "$BAT/status")" "$(cat "$BAT/capacity")" \
    "$(awk -v i="$(cat "$BAT/current_now")" -v v="$(cat "$BAT/voltage_now")" \
        'BEGIN{print i/1e6*v/1e6}')"
}

mode=${1:-toggle}
cur_type=$(grep -o '\[[A-Za-z]*\]' "$BAT/charge_types" | tr -d '[]')
cur_end=$(cat "$BAT/charge_control_end_threshold")

if [[ "$mode" == toggle ]]; then
  if [[ "$cur_type" == Custom && "$cur_end" == 55 ]]; then mode=normal; else mode=park; fi
fi

case "$mode" in
  status) show; exit 0 ;;
  park)   type=Custom; start=50; end=55 ;;
  normal) type=Fast;   start=50; end=90 ;;
  *)      echo "usage: ${0##*/} [toggle|park|normal|status]" >&2; exit 2 ;;
esac

echo "before:  $(show)"

# charge_types is a mode selector, so it has to go first or the thresholds mean
# nothing. Writes only take effect on the *next* charge cycle, never mid-charge.
printf '%s\n' "$type"  | sudo tee "$BAT/charge_types" >/dev/null
printf '%s\n' "$start" | sudo tee "$BAT/charge_control_start_threshold" >/dev/null
printf '%s\n' "$end"   | sudo tee "$BAT/charge_control_end_threshold" >/dev/null

sleep 2
echo "$mode:$(printf '%*s' $((8-${#mode})) '')$(show)"

if [[ "$mode" == park && "$(cat "$BAT/capacity")" -lt 55 ]]; then
  echo
  echo "note: at $(cat "$BAT/capacity")% you're below the 55% stop threshold, so it will"
  echo "      charge up to 55 first (~6 min per 5%, with drops) and then park."
fi
