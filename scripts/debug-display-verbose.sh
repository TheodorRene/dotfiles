#!/usr/bin/env bash
# Verbose kernel tracing of a USB-C display hotplug. MUST be run as root:
#
#   sudo ~/dotfiles/scripts/debug-display-verbose.sh
#
# Turns on dynamic debug for the Type-C/UCSI/Thunderbolt stack plus drm.debug
# (CORE|DRIVER|KMS|ATOMIC|DP), traces one or more plug cycles, then ALWAYS
# restores the previous settings on exit, including Ctrl-C.
#
# This is loud. Do not leave it running.

set -u
[ "$(id -u)" -eq 0 ] || { echo "must run as root: sudo $0" >&2; exit 1; }

log="${1:-/var/tmp/display-verbose-$(date +%Y%m%d-%H%M%S).log}"
ddc=/sys/kernel/debug/dynamic_debug/control
drmp=/sys/module/drm/parameters/debug

MODULES=(typec typec_ucsi ucsi_acpi typec_displayport thunderbolt)

prev_drm=$(cat "$drmp" 2>/dev/null || echo 0)
prev_level=$(cut -d' ' -f1 /proc/sys/kernel/printk)

restore() {
  echo
  echo "restoring..."
  [ -w "$drmp" ] && echo "$prev_drm" > "$drmp" 2>/dev/null
  if [ -w "$ddc" ]; then
    for m in "${MODULES[@]}"; do echo "module $m -p" > "$ddc" 2>/dev/null; done
  fi
  echo "$prev_level" > /proc/sys/kernel/printk 2>/dev/null
  echo "drm.debug back to $prev_drm; dynamic debug off"
  echo "trace: $log"
}
trap restore EXIT INT TERM

{
  echo "=== verbose display trace $(date -Is) ==="
  echo "kernel $(uname -r)  BIOS $(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
  echo "drm.debug was: $prev_drm"
  echo
} > "$log"

# 0x02 DRIVER | 0x04 KMS | 0x10 ATOMIC | 0x100 DP.  NOT 0x01 CORE - that is
# drm_ioctl, which sway floods (3.1MB in 16s of normal rendering).
echo 0x116 > "$drmp" || echo "WARN: could not set drm.debug" >&2
for m in "${MODULES[@]}"; do
  echo "module $m +p" > "$ddc" 2>/dev/null || echo "WARN: no dynamic debug for $m" >&2
done
echo 8 > /proc/sys/kernel/printk 2>/dev/null

echo "Tracing -> $log"
echo
echo "Plug the dongle into the SLOW port now. WAIT AT LEAST 20 SECONDS"
echo "without touching it, even if the screen stays dark - the gap we are"
echo "chasing is ~10s of silence. Repeat a few times, both successes and"
echo "failures are useful. Ctrl-C when done."
echo
echo "Do NOT press F9 during this (it segfaulted sway once already)."
echo

journalctl -k -f -n0 --no-pager \
  | grep --line-buffered -iE "ucsi|typec|drm|xe |dp |hpd|link|altmode|mux|tbt|thunderbolt|usb .*(new|disconnect)" \
  | tee -a "$log"
