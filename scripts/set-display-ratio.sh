#!/usr/bin/env bash
# Force a custom display mode on a wlroots/sway output that the panel's EDID
# does not advertise (e.g. a 16:9 mode on a native-16:10 laptop panel).
#
# wdisplays/wlr-randr only offer modes the output reports, so they can't do
# this. Sway's `output <name> mode --custom` can, but a fixed eDP panel may
# reject it or letterbox (black bars). This script applies it and then VERIFIES
# what actually took effect, so you know whether it worked.
#
# Usage:
#   set-display-ratio.sh                  # apply default 1920x1080@60 to eDP-1
#   set-display-ratio.sh 1600x900@60      # apply a specific custom mode
#   set-display-ratio.sh 1920x1080 DP-1   # custom mode on a different output
#   set-display-ratio.sh --revert         # restore the native EDID mode
#   set-display-ratio.sh --list           # show the output's advertised modes
set -euo pipefail

OUTPUT="eDP-1"
MODE="1920x1080@60Hz"

die() { echo "error: $*" >&2; exit 1; }
command -v swaymsg >/dev/null || die "swaymsg not found (are you in a sway session?)"
command -v jq      >/dev/null || die "jq not found (needed to read output state)"

# --- argument parsing -------------------------------------------------------
case "${1:-}" in
  --list)
    swaymsg -t get_outputs | jq -r --arg o "$OUTPUT" \
      '.[] | select(.name==($ARGS.positional[0] // $o)) // .[]
       | "OUTPUT \(.name): native modes ->",
         (.modes[] | "  \(.width)x\(.height)@\(.refresh/1000)Hz")' \
      --args "${2:-$OUTPUT}"
    exit 0
    ;;
  --revert)
    OUTPUT="${2:-$OUTPUT}"
    # Pick the highest-res native mode the panel advertises and restore it.
    native=$(swaymsg -t get_outputs | jq -r --arg o "$OUTPUT" \
      '.[] | select(.name==$o) | .modes | max_by(.width*.height)
       | "\(.width)x\(.height)@\(.refresh/1000)Hz"')
    [ -n "$native" ] || die "output '$OUTPUT' not found"
    echo "Restoring native mode $native on $OUTPUT ..."
    swaymsg -q -- output "$OUTPUT" mode "$native"
    exit 0
    ;;
  -h|--help)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  "") ;;                       # no args -> defaults
  *)
    MODE="$1"
    [ -n "${2:-}" ] && OUTPUT="$2"
    ;;
esac

# Normalise "WxH" -> "WxH@60Hz", and "WxH@60" -> "WxH@60Hz"
[[ "$MODE" == *@* ]] || MODE="${MODE}@60Hz"
[[ "$MODE" == *Hz ]] || MODE="${MODE}Hz"

want_w="${MODE%%x*}"
rest="${MODE#*x}"
want_h="${rest%%@*}"

# --- confirm the output exists ---------------------------------------------
swaymsg -t get_outputs | jq -e --arg o "$OUTPUT" '.[] | select(.name==$o)' >/dev/null \
  || die "output '$OUTPUT' not found. Available: $(swaymsg -t get_outputs | jq -r '[.[].name]|join(", ")')"

echo "Attempting custom mode $MODE on $OUTPUT ..."
# --custom tells sway to compute CVT timings and not require the mode in EDID.
# The leading `--` stops swaymsg from eating `--custom` as its own option.
if ! swaymsg -q -- output "$OUTPUT" mode --custom "$MODE"; then
  die "sway rejected the custom mode. The panel/driver likely won't accept $MODE."
fi

# --- verify what actually took effect --------------------------------------
read -r got_w got_h < <(swaymsg -t get_outputs | jq -r --arg o "$OUTPUT" \
  '.[] | select(.name==$o) | "\(.current_mode.width) \(.current_mode.height)"')

if [ "$got_w" = "$want_w" ] && [ "$got_h" = "$want_h" ]; then
  echo "OK: $OUTPUT is now ${got_w}x${got_h} (ratio $(awk "BEGIN{printf \"%.2f\", $got_w/$got_h}"))."
  echo "If you see black bars top/bottom, that's the panel letterboxing 16:9 onto a 16:10 surface."
  echo "Revert any time with:  $0 --revert${OUTPUT:+ $OUTPUT}"
else
  echo "WARNING: requested ${want_w}x${want_h} but output is ${got_w}x${got_h}." >&2
  echo "The driver silently ignored the custom mode (common on fixed eDP panels)." >&2
  exit 1
fi
