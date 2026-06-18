#!/usr/bin/env bash
# Emit the active keyboard layout as a short code for a waybar custom module.
# Event-driven: prints once, then re-prints whenever sway reports an input change.
set -uo pipefail

emit() {
  local name
  name="$(swaymsg -t get_inputs | jq -r 'first(.[] | select(.type=="keyboard")).xkb_active_layout_name')"
  case "$name" in
    English*)   echo "US" ;;
    Norwegian*) echo "NO" ;;
    *)          echo "${name:0:2}" ;;
  esac
}

emit
swaymsg -t subscribe '["input"]' | while read -r _; do
  emit
done
