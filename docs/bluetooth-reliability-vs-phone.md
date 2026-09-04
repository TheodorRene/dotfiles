# Why Bluetooth headphones connect worse here than on a phone

Investigated 2026-09-04, prompted by the Bose cans ("Thrash Cans") being far
flakier to connect on this laptop than on a phone.

## The setup, as measured

| Thing | Value |
| --- | --- |
| Controller | `hci0`, Intel, PCI `00:14.7` (CNVi) |
| Wifi | `wlp0s20f3`, `iwlwifi`, PCI `00:14.3` — **same CNVi package** |
| BlueZ | 5.85 |
| Audio | PipeWire 1.6.2 + WirePlumber 0.5.13 (`libspa-0.2-bluetooth`) |
| Headphones | `C8:7B:23:50:4F:23`, Bose (vendor `0x009E`), paired + bonded + trusted |
| Active profile | `a2dp-sink`, codec **AAC** (`api.bluez5.codec: aac`) |

Note the headphones expose `Battery Percentage` over BlueZ, so battery
reporting already works — that's not part of the problem.

## Causes, ranked

1. **Multipoint arbitration, and the phone is the favourite.** Bose cans page
   their *last-connected device* on power-on. A phone is in-pocket, awake, and
   always page-scanning, so it wins that race and occupies a slot. There is no
   Bose Connect app on Linux to arbitrate. **Not fixable from this side** — the
   workaround is Bluetooth off on the phone.
2. **`FastConnectable = false`** (BlueZ default; `/etc/bluetooth/main.conf` was
   entirely untouched, every line commented). This governs the page-scan
   interval: with it off the controller only listens for incoming connections in
   short, widely-spaced windows, so the headphones' page attempt often just
   misses. Phones page-scan aggressively and eat the ~1 mA. **Highest-value
   local knob.**
3. **Three daemons must agree instead of one.** `bluetoothd` owns the link,
   PipeWire/WirePlumber owns the A2DP transport, and `blueman` is a third agent
   on the bus. The Linux-only failure mode — "connected, but no sink appears" —
   lives in that seam. A phone has one integrated stack and no such seam.
4. **AAC.** PipeWire's AAC encoder (fdk-aac) is the least mature codec path in
   the stack, and QC-series Bose offer only SBC + AAC — no LDAC/aptX to fall
   back to. Phones ship vendor-tuned AAC with real adaptive bitrate. Shows up as
   stutter and dropped links under load, not as failure to connect.
5. **Shared RF front-end + power-save jitter.** BT and wifi are one CNVi part
   sharing antennas, and wifi power save was **on** (see below).
6. **Antenna geometry.** Laptop antennas sit in the chassis behind metal with a
   body between them and the user's head; a phone is ~30 cm away in a pocket.
   Not fixable.

### Dead end, recorded so it isn't re-theorised

**2.4 GHz co-channel interference from wifi is not the cause.** Wifi was
associated on **6 GHz, channel 53 (6215 MHz) at 160 MHz width** — nowhere near
the BT band. The shared front-end still time-slices (cause 5), but in-band
collision does not apply here.

## The `br-connection-busy` error (investigated 2026-09-04)

The error blueman shows when you click Connect and it says "Failed". **Nothing
failed** — BlueZ declined to start a *second* attempt on top of one already
running. It is `org.bluez.Error.InProgress`, and in BlueZ 5.85 there is exactly
one site that emits it, `connect_profiles()` in `src/device.c`:

```c
if (dev->pending || dev->connect || dev->browse)
        return btd_error_in_progress_str(msg, ERR_BREDR_CONN_BUSY);
```

`ERR_BREDR_CONN_BUSY` is `"br-connection-busy"` (`src/error.h`). blueman maps
`org.bluez.Error.InProgress` to `DBusInProgressError`
(`blueman/bluez/errors.py:119`) and renders it as a failure. So the connection
that eventually succeeds is the attempt that was *already in flight* — the
clicks contribute nothing.

**Two independent actors keep an attempt in flight:**

1. **blueman's AutoConnect applet plugin.** Its own description: *"Tries to
   auto-connect to configurable services on start and every 60 seconds."* It is
   configured for the Bose with blueman's `GENERIC_CONNECT` sentinel UUID
   (`ManagerDeviceMenu.py:132`), i.e. connect **all** profiles:
   ```
   org.blueman.plugins.autoconnect services
     [('C8:7B:23:50:4F:23', '00000000-0000-0000-0000-000000000000')]
   ```
2. **bluetoothd's `[Policy]` plugin**, at defaults `ReconnectAttempts=7`,
   `ReconnectIntervals=1,2,4,8,16,32,64`.

**Why the in-flight attempt is slow:** a generic connect drags in profiles this
machine has no use for. Over 30 days of journal:

```
     49 io data for Hands-Free Voice gateway
     48 io data for Phone Book Access
```

— HFP and PBAP channels collapsing (`ext_io_disconnected`), plus
`record_cb() Unable to get Hands-Free Voice gateway SDP record: Connection reset
by peer`. All of it sits in `dev->pending` while A2DP is still negotiating.

Observed click pattern, both rejected ~6 s apart, then eventual success:

```
2026-09-03T10:57:48  br-connection-busy
2026-09-03T10:57:54  br-connection-busy
2026-09-03T16:15:06  br-connection-busy
2026-09-03T16:15:12  br-connection-busy
```

**Practical upshot: don't click twice.** blueman retries every 60 s regardless.

## Applied

### 1. `FastConnectable = true` — applied 2026-09-04

```bash
sudo sed -i 's/^#FastConnectable = false/FastConnectable = true/' /etc/bluetooth/main.conf
sudo systemctl restart bluetooth
```

**This is an in-place edit of a package conffile, not a symlink from this repo** —
`bluetoothd` reads only `/etc/bluetooth/main.conf` and supports **no `conf.d`
drop-ins**, so there is nothing to symlink without forking the whole
heavily-commented distro file. Re-run the `sed` after a reinstall. Verify with:

```bash
grep -vE '^\s*(#|$)' /etc/bluetooth/main.conf   # expect: [General] / FastConnectable = true
```

### 2. Wifi power save off — applied 2026-09-04

Wifi power save was on because **Ubuntu's `network-manager` package ships it on**:
`/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf` sets
`wifi.powersave = 3` (3 = enable). No connection profile overrode it — every
profile reported `802-11-wireless.powersave: default` — so that one file governed
the whole machine.

Fixed with a repo-tracked drop-in rather than editing the conffile (dpkg would
prompt on upgrade): `etc/NetworkManager/conf.d/zz-wifi-powersave-off.conf`,
installed by `scripts/install-wifi-powersave-off.sh`.

**Naming trap:** NetworkManager reads `conf.d` in **alphanumerical** order and
later values win, so the override must sort *after* `default-wifi-powersave-on.conf`.
A numeric prefix (`90-`, `99-`) sorts **before** letters and would silently lose;
hence `zz-`.

Also note the setting only lands on the interface at (re)association, so
`nmcli general reload` alone doesn't change the live state — the installer
follows it with `iw dev <dev> set power_save off`.

Values: `0` = use default, `1` = leave alone, `2` = disable, `3` = enable.

### 3. PBAP (phonebook) server off — applied 2026-09-04

The Bose connect as a PBAP **client** and pull this laptop's phonebook on every
connect; `obexd` answered by waking **evolution-data-server**
(`evolution-source-registry`, `evolution-addressbook-factory`) to serve contacts
a pair of headphones cannot use.

`obex.service` is a **user** unit, so this needs no root. Drop-in tracked at
`systemd/user/obex.service.d/override.conf`, symlinked by `symlinkifier.pl`:

```ini
[Service]
ExecStart=
ExecStart=/usr/libexec/bluetooth/obexd --noplugin=pbap
```

The bare `ExecStart=` is required — systemd appends otherwise, and a `Type=dbus`
unit refuses two `ExecStart` lines.

**Verified:** obexd's own debug output prints `Excluding pbap` while every other
plugin still loads (filesystem, bluetooth, pcsuite, opp, ftp, irmc, mas, mns,
and the client modules). On the adapter, exactly one advertised UUID
disappeared — `Phonebook Access Server (0000112f)` — with `OBEX Object Push`,
`OBEX File Transfer`, `IrMC Sync`, `Message Access Server`, `Message
Notification` and `Phonebook Access *Client*` all still present (18 UUIDs, down
from 19). Audio was unaffected throughout.

**Gotcha that will mislead you: `obexd` defers plugin loading by ~30 seconds
after start.** Observed twice, exactly 30 s between `OBEX daemon 5.85` and
`Excluding pbap`. Until then the adapter advertises only its 11 non-obexd
profiles, so a check run 1–25 s after `systemctl --user restart obex.service`
shows *all* OBEX profiles missing and looks like the change broke everything.
Wait past 30 s before believing any UUID count.

## Open / optional — not applied

- **Narrow blueman's autoconnect to A2DP only**, so the generic connect stops
  dragging HFP/PBAP through `dev->pending` on every retry:
  ```bash
  gsettings set org.blueman.plugins.autoconnect services \
    "[('C8:7B:23:50:4F:23', '0000110b-0000-1000-8000-00805f9b34fb')]"
  ```
  **Deliberately not applied — needs verification first.** It means only A2DP is
  connected up front, so HFP (headset mic, for Slack huddles) would have to be
  connected on demand when an app opens the mic. That *should* work via
  WirePlumber's autoswitch, but it is unverified here, and "find out mid-call" is
  the wrong way to learn. Test by forcing the profile with `wpctl` right after
  applying; revert to the `00000000-…` sentinel if the mic does not come up.
- **Force SBC-XQ instead of AAC** for robustness (cause 4). Would be a
  WirePlumber drop-in at `~/.config/wireplumber/wireplumber.conf.d/` dropping
  `aac` from `bluez5.codecs`. Quality difference on QC-series is small; worth it
  only if dropouts (rather than failures to connect) become the main annoyance.
- **`bluetooth.autoswitch-to-headset-profile false`** (`wpctl settings --save`)
  to stop apps dragging the cans from A2DP into HFP.

## Reference: how to inspect this stack

`pactl` is **not installed** — use `wpctl`/`pw-dump` instead.

```bash
bluetoothctl show                       # adapter state
bluetoothctl info <MAC>                 # paired/bonded/trusted, battery, UUIDs
wpctl status                            # devices, sinks, sources
pw-dump | grep -oE '"api\.bluez5\.[a-z.]+": "[^"]*"'   # live profile + codec
iw dev <dev> get power_save             # wifi power save state
iw dev                                  # associated channel/width
```

For the OBEX/PBAP side:

```bash
systemctl --user show obex.service -p ExecStart   # confirm --noplugin=pbap
bluetoothctl show | grep -c UUID                  # 18 = PBAP off; 11 = still inside obexd's 30s delay
journalctl --user -u obex.service | grep -i pbap  # expect "Excluding pbap"
journalctl -g 'br-connection' --since '-30 days'  # the blueman rejections
gsettings get org.blueman.plugins.autoconnect services
```
