#!/usr/bin/env bash
# disk-space-warning.sh — desktop notification when / has less than MIN_GB free.
# Run hourly by disk-space-warning.timer.
#
# Usage: disk-space-warning.sh [MIN_GB]   # defaults to 30
set -uo pipefail

MIN_GB="${1:-30}"
free_gb=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')

if [ "$free_gb" -lt "$MIN_GB" ]; then
  notify-send -u critical -i drive-harddisk "Disk almost full" \
    "${free_gb} GB free on /. Rust build dirs are the usual cause: cargo-sweep-targets.sh 3"
fi
