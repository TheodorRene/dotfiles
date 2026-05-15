# i3 Touchpad Configuration

## Touchpad Device

The touchpad is identified as `VEN_04F3:00 04F3:31D1 Touchpad` and uses the **Synaptics** driver.

## Toggle Touchpad

Keybinding: `$mod+Shift+t`

This runs `~/.config/i3/toggle-touchpad.sh`, which uses `xinput` to enable/disable the touchpad and sends a desktop notification.

## Palm Detection

Enabled via xinput on startup:

```bash
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Palm Detection" 1
```

Palm dimensions (width, pressure) can be tuned:

```bash
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Palm Dimensions" 8 200
```

Default is `10 200`.

## Disable Touchpad While Typing

`syndaemon` monitors keyboard input and disables the touchpad during typing.

```bash
syndaemon -i 1 -d -K -R
```

### Flags

| Flag | Description |
|------|-------------|
| `-i 1` | Idle time (seconds) — touchpad is disabled until 1s after the last keypress |
| `-d` | Daemonize (run in background) |
| `-K` | Ignore modifier keys (Ctrl, Shift, etc.) so shortcuts don't disable the touchpad |
| `-R` | Use XRecord instead of polling (lower resource usage) |

### Notes

- `-t` flag allows tapping while typing — remove it for stricter palm rejection
- Only one instance should run at a time; multiple instances cause issues
- The i3 config uses `exec_always` so it restarts on config reload — be aware this can spawn duplicates if `syndaemon` doesn't get killed

## Two-Finger Scrolling

Current state: vertical enabled, horizontal disabled (`1, 0`).

```bash
# Enable both vertical and horizontal two-finger scrolling
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Two-Finger Scrolling" 1 1

# Vertical only
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Two-Finger Scrolling" 1 0
```

### Scroll Speed

Controlled by `Synaptics Scrolling Distance` (vertical, horizontal). Lower values = faster scrolling. Default is `80, 80`.

```bash
# Faster scrolling
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Scrolling Distance" 50 50
```

### Edge Scrolling

Edge scrolling is an alternative to two-finger scrolling (scrolls by dragging along the edge of the touchpad). Currently enabled for vertical only (`1, 0, 0`).

```bash
# Disable edge scrolling if you prefer two-finger only
xinput set-prop "VEN_04F3:00 04F3:31D1 Touchpad" "Synaptics Edge Scrolling" 0 0 0
```

## Useful Commands

```bash
# List all touchpad properties
xinput list-props "VEN_04F3:00 04F3:31D1 Touchpad"

# Check if syndaemon is running
ps aux | grep syndaemon

# Kill all syndaemon instances
killall syndaemon
```
