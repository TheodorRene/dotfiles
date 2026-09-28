#!/usr/bin/env bash
# Snapshot the external-display state. Run while the monitor IS connected,
# ideally while it is visibly dropping frames.
out="${1:-/tmp/display-state-$(date +%Y%m%d-%H%M%S).txt}"
{
  echo "=== $(date -Is) ==="
  echo
  echo "--- sway outputs ---"
  # Under sudo, root has no SWAYSOCK - drop back to the invoking user.
  as_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
      sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$SUDO_USER")" "$@"
    else
      "$@"
    fi
  }
  as_user swaymsg -t get_outputs | jq -r '.[] | "\(.name) active=\(.active) \(.make) \(.model) \(.current_mode.width)x\(.current_mode.height)@\(.current_mode.refresh/1000)Hz scale=\(.scale) adaptive_sync=\(.adaptive_sync_status)"' 2>/dev/null
  echo
  echo "--- DRM connectors ---"
  for c in /sys/class/drm/card*-*; do
    [ -e "$c/status" ] || continue
    echo "$(basename "$c"): $(cat "$c/status") enabled=$(cat "$c/enabled" 2>/dev/null)"
  done
  echo
  echo "--- DP link rate / lane count (needs root) ---"
  # debugfs shows the same card under several aliases (PCI address, minor,
  # 128+minor). Pick the PCI-addressed one so we report each connector once.
  card=$(ls -d /sys/kernel/debug/dri/[0-9a-f][0-9a-f][0-9a-f][0-9a-f]:* 2>/dev/null | head -1)
  [ -z "$card" ] && card=$(ls -d /sys/kernel/debug/dri/*/ 2>/dev/null | head -1)
  echo "(card: ${card:-none found - are you root?})"
  for d in "$card"/DP-*; do
    [ -d "$d" ] || continue
    echo "== ${d##*/}"
    for f in "$d"/*; do
      [ -f "$f" ] || continue
      printf '   %-34s %s\n' "${f##*/}:" "$(head -c 400 "$f" 2>/dev/null | tr '\n' ' ')"
    done
  done
  echo
  echo "--- USB-C alt modes ---"
  for a in /sys/class/typec/*/*.[0-9]; do
    [ -d "$a" ] || continue
    echo "$a svid=$(cat "$a/svid" 2>/dev/null) active=$(cat "$a/active" 2>/dev/null) vdo=$(cat "$a/vdo" 2>/dev/null)"
  done
  echo
  echo "--- kernel display/typec errors, last 10 min ---"
  journalctl -k --since "10 min ago" --no-pager \
    | grep -iE "atomic update|underrun|link training|ucsi|typec|drm.*ERROR|hpd" || echo "(none)"
} > "$out" 2>&1
echo "wrote $out"
