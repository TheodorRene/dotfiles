#!/usr/bin/env bash
# Toggle a floating tmux scratchpad terminal (app_id=scratch-tmux).
# First press launches it (placed/shown by the for_window rule in sway/config);
# later presses show/hide it.
set -uo pipefail

if swaymsg -t get_tree \
   | jq -e '[recurse(.nodes[]?, .floating_nodes[]?) | select(.app_id=="scratch-tmux")] | length > 0' \
   >/dev/null 2>&1; then
  swaymsg '[app_id="scratch-tmux"] scratchpad show'
else
  exec alacritty --class scratch-tmux -e tmux new-session -A -s main
fi
