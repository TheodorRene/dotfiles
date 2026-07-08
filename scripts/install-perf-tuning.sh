#!/usr/bin/env bash
# Install performance tuning that isn't covered by the oomd/zram setup:
#   - VM sysctls tuned for the zram-primary swap layout (see the conf for why)
#   - disable NetworkManager-wait-online, which blocks boot ~5s waiting for the
#     network to be fully up (nothing in a Sway desktop needs that gate)
#
# Symlinks the sysctl drop-in into /etc so a reinstall just re-runs this.
# Companion to scripts/install-oomd-tuning.sh.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"

SRC_SYSCTL="$DOTFILES/etc/sysctl.d/99-vm-tuning.conf"
DST_SYSCTL="/etc/sysctl.d/99-vm-tuning.conf"

[[ -f "$SRC_SYSCTL" ]] || { echo "missing: $SRC_SYSCTL" >&2; exit 1; }

# --- VM sysctls --------------------------------------------------------------
sudo mkdir -p "$(dirname "$DST_SYSCTL")"
sudo ln -sfn "$SRC_SYSCTL" "$DST_SYSCTL"
sudo sysctl --system >/dev/null

# --- Boot: don't block on network-online -------------------------------------
# Idempotent: disabling an already-disabled unit is a no-op that exits 0.
sudo systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true

echo
echo "== effective VM sysctls =="
for k in vm.page-cluster vm.swappiness vm.vfs_cache_pressure vm.watermark_scale_factor; do
  printf "  %-28s = %s\n" "$k" "$(sysctl -n "$k")"
done
echo
echo "== NetworkManager-wait-online (expect: disabled) =="
systemctl is-enabled NetworkManager-wait-online.service 2>&1 | sed 's/^/  /'
echo
echo "Boot change takes effect next reboot; sysctls are live now."
