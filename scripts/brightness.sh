
if [ $1 == "up" ]; then
    xbacklight -inc 10
else
    xbacklight -dec 10
fi

output="$(cat /sys/class/backlight/intel_backlight/brightness)"

notify-send -t 100 -u low Brightness "${output}"
