#!/usr/bin/env bash
# Hardware inventory for the machine that's about to become the home server.
#
# Run this ON THE SPECTRE, not on the XPS. Any Linux will do — its current OS, an
# Ubuntu live USB, or the NixOS installer ISO. If the Spectre is still on
# Windows, boot a live USB; nothing here writes to disk.
#
#   bash inventory.sh | tee spectre-inventory.txt
#
# Everything here is readable as a normal user: /sys and /proc only, no dmidecode
# (which needs root and adds nothing these files don't have). Missing tools are
# reported as missing rather than failing the run.
set -u

hdr() { printf '\n== %s %s\n' "$1" "$(printf '=%.0s' $(seq 1 $((60 - ${#1}))))"; }
try() { command -v "$1" >/dev/null 2>&1 && "$@" || echo "(no $1)"; }
cat_or() { [ -r "$1" ] && cat "$1" || echo "(absent: $1)"; }

hdr "Identity"
for f in sys_vendor product_name product_version board_name bios_version bios_date; do
  printf '%-16s %s\n' "$f" "$(cat_or /sys/class/dmi/id/$f)"
done

hdr "CPU"
try lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core\(s\)|Socket|MHz|Virtualization'

hdr "Memory"
try free -h
echo "--- is it soldered / are there free slots? (needs root; run if you care)"
echo "    sudo dmidecode -t memory | grep -E 'Size|Locator|Type:|Speed'"

hdr "Disks"
try lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,ROTA
echo "--- SMART needs root: sudo smartctl -a /dev/nvme0n1"

hdr "Graphics"
try lspci -nn | grep -Ei 'vga|3d|display'
echo "--- VAAPI (hardware transcode; decides the Jellyfin/Immich question)"
try vainfo 2>&1 | head -20

hdr "Network"
try ip -br link
echo "--- wired ethernet present?"
ls /sys/class/net | grep -E '^(en|eth)' || echo "NO WIRED NIC (expected — buy a USB3 GbE adapter)"
echo "--- wifi"
try lspci -nn | grep -i network

hdr "TPM (recorded for completeness — the server has no disk encryption)"
if [ -e /sys/class/tpm/tpm0 ]; then
  printf 'tpm0 present. version_major: %s\n' "$(cat_or /sys/class/tpm/tpm0/tpm_version_major)"
  printf 'description:              %s\n' "$(cat_or /sys/class/tpm/tpm0/device/description)"
else
  echo "NO /sys/class/tpm/tpm0 — either absent or disabled in BIOS (F10). Check there"
  echo "before concluding the machine has no TPM; HP ships it disabled on some SKUs."
fi

hdr "Battery (the most likely hardware failure on a 6-7 year old laptop)"
for b in /sys/class/power_supply/BAT*; do
  [ -e "$b" ] || { echo "(no battery found)"; break; }
  echo "--- $b"
  for f in status capacity cycle_count energy_full energy_full_design charge_full charge_full_design manufacturer model_name; do
    [ -r "$b/$f" ] && printf '  %-22s %s\n' "$f" "$(cat "$b/$f")"
  done
  if [ -r "$b/energy_full" ] && [ -r "$b/energy_full_design" ]; then
    awk -v n="$(cat "$b/energy_full")" -v d="$(cat "$b/energy_full_design")" \
      'BEGIN { if (d > 0) printf "  %-22s %.0f%% of design\n", "health", 100*n/d }'
  fi
  if [ -e "$b/charge_control_end_threshold" ]; then
    echo "  charge ceiling         SUPPORTED -> cap it at 60-80% for 24/7 duty"
  else
    echo "  charge ceiling         not exposed by this firmware (common on HP)"
  fi
done
echo
echo "PHYSICAL CHECK, which no command can do: does the bottom panel sit flat, and"
echo "does the trackpad click normally? A bulge means a swollen cell. Stop and"
echo "replace it before running the machine unattended 24/7."

hdr "Firmware / OS"
printf '%-16s %s\n' kernel "$(uname -r)"
printf '%-16s %s\n' boot-mode "$([ -d /sys/firmware/efi ] && echo UEFI || echo 'BIOS/CSM')"
printf '%-16s %s\n' secureboot "$(try mokutil --sb-state 2>&1 | head -1)"

hdr "Not answerable from Linux — check in the BIOS (F10 at boot)"
cat <<'NOTE'
  - "Power on after AC loss" / "AC Recovery". If absent, a long power cut leaves
    the machine off until someone presses the button.
  - TPM enabled (if the section above found nothing).
  - Secure Boot state — plan is to leave it off; lanzaboote is complexity this
    machine doesn't need.
NOTE
