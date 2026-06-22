#!/usr/bin/env bash
# Toggle between laptop-only (eDP-1) and external-only (DP-1) display modes.
set -euxo pipefail

LAPTOP="eDP-1"
EXTERNAL="DP-1"

die()    { notify-send -u critical "Display toggle" "$*" 2>/dev/null; echo "error: $*" >&2; exit 1; }
notify() { notify-send -t 1500 -u low "Display toggle" "$*" 2>/dev/null || true; }

command -v swaymsg >/dev/null || die "swaymsg not found (not in a sway session?)"
command -v jq      >/dev/null || die "jq not found"

outputs="$(swaymsg -t get_outputs)"

is_active() { echo "$outputs" | jq -e --arg o "$1" '.[] | select(.name==$o and .active==true)' >/dev/null; }
exists()    { echo "$outputs" | jq -e --arg o "$1" '.[] | select(.name==$o)' >/dev/null; }

restart_waybar() {
  pkill -x waybar 2>/dev/null || true
  setsid -f waybar >/dev/null 2>&1 || (setsid waybar >/dev/null 2>&1 &)
}

if is_active "$LAPTOP"; then
  # --> go EXTERNAL-ONLY
  exists "$EXTERNAL" || die "External monitor ($EXTERNAL) is not connected — staying on laptop."
  swaymsg -q "output $EXTERNAL enable position 0 0"   # enable auto-selects the preferred mode
  swaymsg -q "output $LAPTOP disable"   # sway auto-migrates eDP-1's workspaces + focus to DP-1
  restart_waybar
  notify "External only ($EXTERNAL)"
else
  # --> go LAPTOP-ONLY
  swaymsg -q "output $LAPTOP enable position 0 0"   # enable auto-selects the preferred mode
  exists "$EXTERNAL" && swaymsg -q "output $EXTERNAL disable"   # auto-migrates DP-1's workspaces + focus to eDP-1
  restart_waybar
  notify "Laptop only ($LAPTOP)"
fi
