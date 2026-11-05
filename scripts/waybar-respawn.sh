#!/usr/bin/env bash
# Runs waybar and starts it again if it crashes.
#
# Waybar 0.15.0's mpris module segfaults some time after a bar is torn down
# (dock/undock, a USB-C monitor drop): ~Mpris() never disconnects its playerctl
# signal handlers, so a later player event calls into the freed module. Fixed
# upstream in a816218637, not in any release yet. Drop this once Ubuntu ships
# waybar >= 0.16 and sway/config is back to plain `waybar`.
#
# Running it again replaces the previous loop and its waybar, so sway's
# exec_always stays safe across reloads. A deliberate stop (`pkill -x waybar`,
# i.e. SIGTERM, or a clean exit) is not respawned.

pidfile="${XDG_RUNTIME_DIR:-/tmp}/waybar-respawn.pid"

# Stop the previous loop first, or it would respawn the waybar killed below.
# Check the name, so a stale pidfile can't kill an unrelated reused PID.
if old=$(cat "$pidfile" 2>/dev/null) && [[ $(cat "/proc/$old/comm" 2>/dev/null) == waybar-respawn* ]]; then
  kill "$old" 2>/dev/null
fi
echo $$ > "$pidfile"
pkill -x waybar

quick_deaths=0
while :; do
  started=$SECONDS
  waybar
  status=$?
  case $status in
    0 | 130 | 143) exit 0 ;; # clean exit, SIGINT, SIGTERM: someone meant it
  esac

  # A broken config makes waybar exit at once; don't spin on that forever.
  if ((SECONDS - started < 10)); then
    ((quick_deaths++))
    if ((quick_deaths >= 5)); then
      notify-send -u critical "waybar" "Exited $quick_deaths times in a row (status $status); not restarting." 2>/dev/null
      exit 1
    fi
  else
    quick_deaths=0
  fi
  echo "waybar-respawn: waybar exited with status $status, restarting" >&2
  sleep 1
done
