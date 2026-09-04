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

## Open / optional — not applied

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
