#!/usr/bin/env bash
# Symlink GDM's system config (enables passwordless autologin for this user) to
# the copy in ~/dotfiles, so a reinstall just re-runs this. Backs up any existing
# real /etc/gdm3/custom.conf first.
#
# Takes effect on the next login/reboot — this does NOT restart GDM (that would
# kill the running graphical session).
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
SRC="$DOTFILES/etc/gdm3/custom.conf"
DST="/etc/gdm3/custom.conf"

[[ -f "$SRC" ]] || { echo "missing: $SRC" >&2; exit 1; }

if [[ -L "$DST" ]]; then
  sudo rm "$DST"
elif [[ -e "$DST" ]]; then
  stamp="$(date +%Y%m%d%H%M%S)"
  sudo cp -a "$DST" "$DST.bak.$stamp"
  echo "backed up $DST to $DST.bak.$stamp"
fi

sudo ln -sfn "$SRC" "$DST"

echo
echo "== linked =="
ls -l "$DST" | sed 's/^/  /'
echo "== autologin lines =="
grep -iE 'AutomaticLogin' "$DST" | sed 's/^/  /'
echo
echo "Autologin takes effect on next reboot."
