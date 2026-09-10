# The USB webcam is unusable for the first minute after plug-in

**Status: APPLIED 2026-09-08.** `80-uvcdynctrl.rules` is masked; the camera now
enumerates immediately. Findings measured the same day with an Anker PowerConf
C200. Kept because the symptom (a webcam that "isn't detected" but shows up fine
in `lsusb`) points nowhere near the actual cause.

## Symptom

Plug in the USB webcam, open any app that wants a camera, and it sees nothing —
for roughly a minute, sometimes longer. Wait, and it starts working with no
intervention. Because it self-heals, it's easy to blame the app, the cable, or
the camera.

`lsusb` shows the device the whole time, `uvcvideo` binds the whole time, and
the `/dev/video*` nodes exist the whole time. The thing that is wrong is their
**permissions**:

```
$ stat -c '%n %A %U:%G' /dev/video33 /dev/video34
/dev/video33 crw------- root:root      # <- devtmpfs defaults, udev never touched it
/dev/video34 crw------- root:root
```

versus the built-in camera, which is correct:

```
/dev/video0  crw-rw---- root:video     # + a uaccess ACL granting trc
```

`root:root 0600` is what the **kernel** creates a devtmpfs node as. It means
udev has not finished processing the add event — not that a rule set it that
way. Two things are missing until it does: `GROUP="video"` (from
`50-udev-default.rules:54`) and the `uaccess` ACL (from `70-uaccess.rules:34`,
which is what actually grants *your* user access on a seat).

## Cause

`/usr/lib/udev/rules.d/80-uvcdynctrl.rules` is a single line:

```
ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="/lib/udev/uvcdynctrl"
```

so **every** UVC camera add event runs `/lib/udev/uvcdynctrl`, a shell script
that ends in:

```sh
cmd="$uvcdynctrlpath -d $DEVNAME --addctrl=$vid:$pid"
```

i.e. `uvcdynctrl -d /dev/video33 --addctrl=291a:3369`. That process spins at
100% CPU for minutes. udev says so itself:

```
09:17:10 (udev-worker)[46312]: video33: Spawned process '/lib/udev/uvcdynctrl' [46365]
                               is taking longer than 59s to complete.
09:17:10 systemd-udevd[1707]:  video33: Worker [46312] processing SEQNUM=13990
                               is taking a long time.
```

`RUN+=` is synchronous: the worker does not finish the event until the program
exits, and udev serialises events for the same syspath. Replugging makes it
worse rather than better — the new `/dev/video33` add event has a byte-identical
syspath to the stuck one, so it queues behind it instead of starting fresh.
Observed sequence:

| time | event |
|---|---|
| 09:16:10 | camera plugged in; `uvcdynctrl` spawned for `video32`, `video33` |
| 09:17:10 | udev logs the 59s warning for both |
| 09:17:22 / 09:17:58 | camera replugged twice (it looked broken) |
| 09:18:02 | current instance appears as `video33` + `video34`, `root:root 0600` |
| ~09:19 | `uvcdynctrl` still in state `R`, burning CPU |
| a few min later | processes gone; nodes now `root:video 0660` + `uaccess` ACL; camera works |

**Not fully established:** the same-syspath collision explains `video33`
staying at devtmpfs defaults, but `video34` is a fresh syspath and was also
stuck, which sibling serialisation alone doesn't account for. Not worth chasing
— the fix is the same either way.

## Why the tool has nothing to do here

`uvcdynctrl` (0.2.5-7, script dated 2014) loads **vendor extension-unit
controls** from XML. The shipped data covers exactly two vendors:

```
$ ls /usr/share/uvcdynctrl/data/
046d  a0c8            # Logitech, and one other
```

The Anker's VID is `291a`. There is no data for it, and none for the built-in
Intel `ipu7` camera either. So the script cannot do anything useful on this
machine — it just burns a minute of camera downtime per plug-in.

It's installed as a **dependency of `guvcview`** (`apt-mark showmanual` doesn't
list it), so `apt purge uvcdynctrl` would drag `guvcview` out with it. That's
why the fix is to mask the rule, not remove the package.

## The fix

```bash
sudo ln -s /dev/null /etc/udev/rules.d/80-uvcdynctrl.rules
sudo udevadm control --reload
```

Then unplug/replug the camera. Verified state:

```
$ ls -l /etc/udev/rules.d/80-uvcdynctrl.rules
lrwxrwxrwx ... /etc/udev/rules.d/80-uvcdynctrl.rules -> /dev/null

$ udevadm test --action=add /sys/class/video4linux/video33 2>&1 | grep uvcdynctrl
File '/etc/udev/rules.d/80-uvcdynctrl.rules' is a mask (symlink to /dev/null).
File '/usr/lib/udev/rules.d/80-uvcdynctrl.rules' is masked by previous entry.

$ stat -c '%n %A %U:%G' /dev/video33
/dev/video33 crw-rw---- root:video
```

`udevadm test` confirming the mask is the check worth keeping — it reads the
real rule set, so it can't be fooled by a typo'd filename the way eyeballing
`/etc/udev/rules.d/` can. The masking symlink **must** have the exact same
basename as the file in `/usr/lib/udev/rules.d/`.

**Not tracked by this repo.** A symlink to `/dev/null` isn't a file that can
live in `etc/`, so unlike the other system configs there is nothing under
`etc/udev/` to symlink in. Re-run the two commands above after a reinstall.

## Reversing it

```bash
sudo rm /etc/udev/rules.d/80-uvcdynctrl.rules
sudo udevadm control --reload
```

## Notes on this camera specifically

Anker PowerConf C200, USB `291a:3369`, serial `ACNV9P1F20605966`, `uvcvideo`.

- `/dev/video33` is the capture node, `/dev/video34` the metadata node. **The
  numbers are not stable** — they depend on how many nodes the built-in `ipu7`
  camera claimed first (it takes `/dev/video0`–`video31`). Match on
  `ID_V4L_PRODUCT` or the `by-id` path, never on a hardcoded number.
- Capture: 2560x1440 / 1920x1080 / 1280x720 / 640x480 / 640x360 / 320x240.
- It also registers a **mic** and takes over as the default PipeWire source
  (`Anker PowerConf C200 Analog Stereo`), displacing `sof-soundwire
  Microphones`. Check with `wpctl status` if audio input suddenly changes when
  the camera is plugged in.
