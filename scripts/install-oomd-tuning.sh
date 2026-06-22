#!/usr/bin/env bash
# Install memory-pressure tuning: zram swap + systemd-oomd policy, so a heavy
# dev load gets compressed-RAM headroom and oomd only kills on genuine sustained
# pressure (instead of nuking the whole session when the small disk swap fills).
#
# Symlinks system config into ~/dotfiles so a reinstall just needs to re-run this.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

SRC_SLICE="$DOTFILES/etc/systemd/system/user.slice.d/50-oomd.conf"
SRC_OOMD="$DOTFILES/etc/systemd/oomd.conf.d/override.conf"
SRC_ZRAM="$DOTFILES/etc/systemd/zram-generator.conf"
DST_SLICE="/etc/systemd/system/user.slice.d/50-oomd.conf"
DST_OOMD="/etc/systemd/oomd.conf.d/override.conf"
DST_ZRAM="/etc/systemd/zram-generator.conf"

for f in "$SRC_SLICE" "$SRC_OOMD" "$SRC_ZRAM"; do
  [[ -f "$f" ]] || { echo "missing: $f" >&2; exit 1; }
done

# --- zram: the generator ships in systemd-zram-generator ---------------------
if [[ ! -e /usr/lib/systemd/system-generators/zram-generator ]]; then
  echo "Installing systemd-zram-generator ..."
  sudo apt-get update -qq
  sudo apt-get install -y systemd-zram-generator
fi

sudo mkdir -p "$(dirname "$DST_SLICE")" "$(dirname "$DST_OOMD")"
sudo ln -sfn "$SRC_SLICE" "$DST_SLICE"
sudo ln -sfn "$SRC_OOMD"  "$DST_OOMD"
sudo ln -sfn "$SRC_ZRAM"  "$DST_ZRAM"

sudo systemctl daemon-reload
sudo systemctl restart systemd-oomd
# (Re)create the zram swap device from the config above.
sudo systemctl restart systemd-zram-setup@zram0.service

echo
echo "== swap devices (zram should be prio 100, ahead of the disk swapfile) =="
swapon --show
echo
echo "== user.slice OOM policy (expect MemoryPressure=kill, Swap=auto) =="
systemctl show user.slice -p ManagedOOMMemoryPressure -p ManagedOOMSwap
echo
echo "== effective oomd.conf =="
systemd-analyze cat-config systemd/oomd.conf | tail -n 20
