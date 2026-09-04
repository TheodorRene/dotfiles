#!/usr/bin/env bash
# Disable wifi power save, so power-save duty cycling stops adding coexistence
# jitter to Bluetooth (wifi and BT share one Intel CNVi RF front-end here).
#
# Symlinks the NetworkManager drop-in from ~/dotfiles so a reinstall just needs
# to re-run this. See docs/bluetooth-reliability-vs-phone.md.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

SRC="$DOTFILES/etc/NetworkManager/conf.d/zz-wifi-powersave-off.conf"
DST="/etc/NetworkManager/conf.d/zz-wifi-powersave-off.conf"

[[ -f "$SRC" ]] || { echo "missing: $SRC" >&2; exit 1; }

sudo mkdir -p "$(dirname "$DST")"
sudo ln -sfn "$SRC" "$DST"

# Reload picks up conf.d without dropping the current connection; the setting
# only lands on the interface at (re)association, hence the explicit `iw` below.
sudo nmcli general reload

for dev in /sys/class/net/wl*; do
  [[ -e "$dev" ]] || continue
  sudo iw dev "$(basename "$dev")" set power_save off
done

echo
echo "== effective wifi.powersave (expect 2) =="
grep -rn 'wifi.powersave' /etc/NetworkManager/conf.d/ /usr/lib/NetworkManager/conf.d/ 2>/dev/null
echo
echo "== per-interface state (expect: Power save: off) =="
for dev in /sys/class/net/wl*; do
  [[ -e "$dev" ]] || continue
  iw dev "$(basename "$dev")" get power_save
done
