#!/usr/bin/env bash
# Sway idle + lock management (started from sway/config via exec_always).
#   - lock the screen after 5 min idle
#   - blank the displays after 10 min idle (wake on input)
#   - lock before the system suspends, so resume needs the password
#     (closes the autologin gap: LUKS only gates a cold boot, not resume)
# exec replaces this shell with swayidle; the config's `pkill swayidle` first
# clears any previous instance so a config reload doesn't stack them.

lock='swaylock -f -i $(find ~/wallpapers -type f | shuf -n1) --scaling fill'

exec swayidle -w \
    timeout 300 "$lock" \
    timeout 600 'swaymsg "output * power off"' \
         resume 'swaymsg "output * power on"' \
    before-sleep "$lock"
