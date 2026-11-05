# External USB-C displays disconnect and reconnect

**Status: APPLIED 2026-10-13: Custom charging policy restored; battery parked.
Root cause unresolved.** Battery charging through the monitor reproducibly exposes
the fault. A UCSI trace now confirms firmware-reported disconnects followed by
temporary source-role attachment and return to sink. This does not establish the
electrical cause or rule out load-dependent PD behaviour. See *2026-10-13 targeted
trace* below for the latest evidence and corrections to earlier conclusions.
Earlier: APPLIED 2026-09-28, OEM kernel `7.0.0-1014-oem`; disconnects persisted.
BIOS 1.11.0. No permanent single-cable fix established.

## 2026-10-13 targeted trace: charging exposes a firmware-reported disconnect

**Latest interpretation; supersedes older “cause found”, “PD negotiation ruled
out”, and “Trickle is cosmetic” claims retained in the investigation history.**

### Additional user-confirmed results

Reported 2026-10-13; exact test dates, durations and power contracts not captured:

- Charging from a **different laptop port with the display connected works**.
  The earlier 13:05–13:33 log alone did not establish this; the user subsequently
  confirmed the simultaneous setup independently.
- The **same Dell disconnects under Windows**, as well as Linux.
- The cable is **vendor-supplied and works with a Mac**. This weakens a generally
  faulty cable/monitor explanation but does not exclude different contracts,
  loads or Dell-specific interoperability.
- Separate video/charging is a working workaround, but the desired outcome is
  reliable **single-cable video and charging**.

### Experiment and verified timing

Same connected monitor, cable and port; charging policy changed without a replug.
Times below are local (CEST). Policy-write times come from sudo journal entries;
those entries record the destination path, not the value written. Values are
established by the user's commands and subsequent sysfs readbacks.

| Time | Observation |
|---|---|
| 15:24:10, 15:28:31, 15:29:59, 15:31:27 | Repeated altmode warnings during the first charging period; user felt interruptions |
| 15:31:38 | User writes `Custom`; **11 seconds after** the last warning |
| 15:32:07 | BAT0: `Not charging`, 62%, `current_now=1000` µA, `voltage_now=11917000` µV (~0.012 W) |
| 15:31:38–15:51:41 | No UCSI errors logged during this parked interval |
| 15:45:55 | Timestamp in the trace filename; recording starts while parked |
| 15:51:41 | User writes `Trickle` |
| 15:51:56 | BAT0: `Charging`, 62%, 2.698 A × 12.203 V = **32.9 W**; `[Trickle]` readback |
| 15:52:14–15 and 15:52:43–44 | Two new interruptions; both captured by UCSI tracing |
| 15:52:51 | User writes `Custom` again |
| 15:53:30 | BAT0: `Not charging`, 62%, 1 mA × 11.894 V = **0.012 W**; no later UCSI errors in that journal check |

The user reported stopping the recording after restoring Custom. **Do not assume
a full 60-second post-change capture**: the inspection above was only 39 seconds
after the command. The repeated off/on/off association is useful evidence, not
proof of a particular electrical mechanism. Bursty events also make a simple
constant-rate Poisson calculation from the earlier short sample unreliable.

### What the trace actually shows

Saved locally, **not tracked by this repo**:
`/var/tmp/usbc-20261013-154555.dat`. Read successfully without root:

```sh
trace-cmd report -i /var/tmp/usbc-20261013-154555.dat
```

Selected first-cycle output (timestamps are monotonic seconds, not wall time):

```text
24848.234884: ucsi_connector_change: port0 status: change=4000, opmode=1, connected=0, sourcing=0, partner_flags=0, partner_type=0, request_data_obj=428709c2, BC status=0
24848.828659: ucsi_connector_change: port0 status: change=4000, opmode=4, connected=1, sourcing=1, partner_flags=1, partner_type=2, request_data_obj=428709c2, BC status=1
24848.960477: ucsi_connector_change: port0 status: change=0060, opmode=3, connected=1, sourcing=1, partner_flags=1, partner_type=2, request_data_obj=1384b12c, BC status=1
24850.091859: ucsi_connector_change: port0 status: change=1000, opmode=4, connected=1, sourcing=0, partner_flags=3, partner_type=2, request_data_obj=1384b12c, BC status=1
24850.693438: ucsi_register_altmode: [FAILED TO PARSE] recipient=1 svid=65281 mode=1 vdo=4278296643
24851.263806: ucsi_connector_change: port0 status: change=0060, opmode=3, connected=1, sourcing=0, partner_flags=3, partner_type=2, request_data_obj=428709c2, BC status=1
```

Second cycle: disconnected at `24876.953129`, connected as source at
`24877.424539`, back to sink at `24878.694752`, previous RDO restored at
`24879.893103`. Thus both cycles show **firmware reporting disconnected →
connected as source → sink**, with roughly 0.5 s to reconnect and another
1–1.5 s to return to sink. Altmode output has a **trace-report parsing problem**;
the raw fields remain available (`65281 = 0xff01`, `4278296643 = 0xff01a043`).
Do not confuse `[FAILED TO PARSE]` with a hardware registration failure.

**Verified:** this is not merely repeated warning text; the controller reports
`connected=0`. **Not established:** actual CC/VBUS waveforms, who initiated the
failure, whether there was a PD hard reset, or whether the temporary source role
is anything other than recovery behaviour. A PD hard reset is not synonymous
with physical Type-C detachment.

**Capture limitation:** only connector-change and altmode events appeared;
**no command events** appeared despite requesting `ucsi:*`. Absence here cannot
prove Linux sent no reset. Next investigation: inspect the running kernel's
available events and trace formats, determine why command events are missing,
then capture commands alongside status. Electrical transients and on-wire PD
traffic may ultimately need a suitable PD analyser.

### Driver-source findings: two misleading names

Upstream source inspected 2026-10-13; **not exact-OEM-build verification** (the
Ubuntu source fetch was denied). Running build: `7.0.0-1015.15-oem`, base 7.0.14.

- [`dell-laptop.c`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/dell/dell-laptop.c)
  maps `{ BAT_PRI_AC_MODE_TOKEN, POWER_SUPPLY_CHARGE_TYPE_TRICKLE }`.
  **`Trickle` selects Dell's Primarily AC Use policy, not a low-current command.**
  The store path writes a firmware mode token. Calling it cosmetic or ignored
  was incorrect; the measured full-rate charge is compatible with this mapping.
  BIOS `PrimAcUse` is therefore not a demonstrated new way to slow-charge.
- [`ucsi/psy.c`](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/ucsi/psy.c)
  derives USB-C `current_now` from `rdo_op_current(con->rdo)` and `voltage_now`
  from a selected source PDO. **These are contract-related cached values, not
  measured cable current/voltage.** Do not multiply them into measured input
  power or confuse `voltage_max` with the active profile. BAT0 measurements are
  separate. These UCSI getters do not issue fresh PD commands in the inspected
  source, weakening the theory that our status reads caused the interruption.
- [`ucsi/trace.h`](https://github.com/torvalds/linux/blob/master/drivers/usb/typec/ucsi/trace.h)
  defines connector-status and command tracepoints. The loaded module has
  tracepoint sections; `trace-cmd` 3.3.3 is installed. Direct access to
  `/sys/kernel/tracing/available_events` required root here.

### Reproduce the capture and restore parking

User runs the root commands in their own terminal. Record while parked first:

```sh
sudo trace-cmd record \
  -B usbc-diagnosis \
  -e 'ucsi:*' \
  -o "/var/tmp/usbc-$(date +%Y%m%d-%H%M%S).dat" \
  sleep 900
```

In another terminal, reproduce the same charging-policy transition:

```sh
date -Is
echo Trickle | sudo tee /sys/class/power_supply/BAT0/charge_types
```

After an interruption, reverse the test change and verify charging stops:

```sh
date -Is
echo Custom | sudo tee /sys/class/power_supply/BAT0/charge_types
cat /sys/class/power_supply/BAT0/status
cat /sys/class/power_supply/BAT0/current_now
```

With the existing 50/55 thresholds and battery above 55%, observed end state was
`Not charging` and `1000` µA. Leave the trace running another 60 seconds, then
Ctrl+C in its terminal to finish/save. The recording enables diagnostic tracing,
not a charging/display policy; charge writes are firmware-backed sysfs changes,
not repository deployment. Original pre-experiment settings and their reversal
are under *Live changes*. No permanent fix or new service was installed here.

## Symptom

External displays on USB-C drop out and come back by themselves. Reported
2026-09-28. The monitor is an **LG 27U730A** ("LG ULTRAFINE" in its EDID). Two
problems, one per cable (2026-09-30):

- **Laptop USB-C → the monitor's USB-C input** gives 4K60, but the connection
  drops and re-attaches about every 30 s.
- **Laptop USB-C → a no-name USB-C→HDMI adapter → the monitor's HDMI input** is
  stable, but tops out at **4K30**.

 The same kind of fault was traced on 2026-09-11 (kernel
`7.0.0-31-generic`, BIOS 1.9.0) with `scripts/watch-display-hotplug.sh`. Those
traces are in `/var/tmp/display-hotplug-20260911-*.log`, plus
`display-state-*.txt` and a root-owned `display-verbose-*.log`. None of them
are in the repo.

Two different setups show up in the logs:

| When | Port (UCSI con) | What's attached | DP altmode VDO pair in the warning |
|---|---|---|---|
| 2026-09-11 | port2 (con3), the non-Thunderbolt port | hub dongle: VIA hub `2109:0817`/`2109:2817` + RTL8153 ethernet `0bda:8153` | `0xff01a043` vs `0x00000c05` |
| 2026-09-28, 2026-09-30 | port0 (con1) | **the monitor's own USB-C input** (direct cable): DisplayPort only, no USB devices enumerate (`lsusb` shows only root hubs + the internal Synaptics `06cb:0701`) | `0xff01a043` vs `0x00140045` |
| 2026-09-30 | port0 (con1) | USB-C→HDMI adapter `343c:0000`, vendor string `xxxxxxxx`, product "USB Type-C Digital AV Adapter" | `0xff01a843` vs `0x00000405` |

Decoding the second VDO of each pair (DisplayPort Capabilities, USB PD spec;
Linux's `DP_CAP_PIN_ASSIGN_UFP_D` macro):

| VDO | Connector | DP pin assignments | Meaning |
|---|---|---|---|
| `0x00000c05` (hub) | plug | C, D | D = **2 DP lanes** + USB 3. The 2026-09-11 debugfs snapshot shows `i915_dp_max_lane_count: 2` |
| `0x00140045` (monitor) | receptacle (bit 6) | C, E | 4 DP lanes |
| `0x00000405` (adapter) | plug | C | 4 DP lanes |

## Evidence

The kernel prints this **every time** a display is attached, on both kernels
and both BIOS versions:

```
ucsi_acpi USBC000:00: con1: Firmware bug: duplicate partner altmode SVID 0xff01 (VDO 0xff01a043 vs 0x00140045) at offset 1, ignoring. Please update your system firmware.
ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-70)
```

`0xff01` is the DisplayPort alternate mode. The first VDO in each pair is
`0xff01a043` for the hub and the monitor, and `0xff01a843` for the adapter. It
has the SVID in its top half, which a DP Capabilities VDO never does, so it's
the bogus entry and the second one is the device's real DP capabilities.
**Theorised, not verified.**

The 2026-09-11 trace shows the **whole Type-C partner** being removed and
re-added, not just the DP link. The hub and ethernet go with it, roughly every
15-30 s:

```
11:50:32.879 KERNEL usb 3-4: USB disconnect, device number 13
11:50:32.884 KERNEL usb 2-3: USB disconnect, device number 14
11:50:32.889 KERNEL r8152-cfgselector 2-3.1: USB disconnect, device number 15
11:50:32.986 UEVENT remove   .../typec/port2/port2-partner/port2-partner.0 (typec)
11:50:32.990 UEVENT remove   .../typec/port2/port2-partner (typec)
11:50:35.304 UEVENT add      .../typec/port2/port2-partner (typec)
11:50:48.121 UEVENT remove   .../typec/port2/port2-partner (typec)
11:50:51.845 UEVENT add      .../typec/port2/port2-partner (typec)
11:50:52.630 KERNEL ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-5)
11:50:54.895 UEVENT add      .../typec/port2/port2-partner/port2-partner.0 (typec)
11:50:55.377 KERNEL ucsi_acpi USBC000:00: con3: Firmware bug: duplicate partner altmode SVID 0xff01 ...
```

When DP did come up on that port, it took **~10 s** after the altmode went
active (`11:53:39.489 ff01:yes` → `11:53:49.389 DP-1=connected`). That delay is
why `display-notify.service` exists.

## Candidate fix: Ubuntu's OEM kernel

Ubuntu's OEM kernel changelog has an entry matching this warning, added in
**`linux-oem-7.0` 7.0.0-1012**:

```
  * USB-C alt mode dropped with false firmware bug warning on Dell systems
    (LP: #2162695)
    - Revert "usb: typec: ucsi: Detect and skip duplicate altmodes from buggy
      firmware"
    - Revert "usb: typec: ucsi: Add duplicate detection to nvidia registration
      path"
    - Revert "usb: typec: ucsi: yoga_c630: Remove redundant duplicate altmode
      handling"
    - usb: typec: ucsi: Detect and skip duplicate altmodes from buggy firmware
    - usb: typec: ucsi: Add duplicate detection to nvidia registration path
    - usb: typec: ucsi: yoga_c630: Remove redundant duplicate altmode handling
```

The generic `linux 7.0.0-34.34` changelog has the **original** duplicate-detection
patches (lines ~6327-6329) but **not** the revert-and-reapply, and doesn't
mention LP #2162695. So on the kernel currently running, this code is the
version the OEM kernel had to replace. **Verified from both changelogs on
2026-09-28.**

What is **not** established:

- **That this bug causes the disconnects.** The warning text and the bug title
  match. (Since tested: it doesn't. See *Result* below.) The 2026-09-11 pattern (the whole partner
  detaching and re-attaching) is a PD-controller-level detach. A bug in how
  Linux registers altmodes doesn't obviously explain that. Treat it as the
  cheapest thing to try, not the answer.
- **Whether mainline 7.2.x has the corrected patches.** Not checked.

Two other display fixes you might look for are **already in the generic
kernel**, so they can't be the difference:

- `drm/i915/lnl+/tc: Fix false disconnect of active DP-alt TC port during long
  HPD pulse` (LP: #2143879). This is a **`SAUCE`** (Ubuntu-only) patch, so
  mainline kernels **don't** have it. It applies here even though the GPU driver
  is `xe`, because `xe` uses the i915 display code.
- `thunderbolt: Defer DP tunnel teardown until display driver is ready`
  (LP: #2155096, also SAUCE): the Thunderbolt DP link being torn down during a
  LUKS boot.

### Result (2026-09-30): no effect on the disconnects

**Dead end, don't re-theorise.** Installed 2026-09-28 (`dpkg.log`). The new code
is running: the warning's wording changed, so the corrected patch is live:

```
con1: Firmware bug: duplicate partner altmode SVID 0xff01 at offset 1, ignoring but please contact the BIOS vendor to fix this issue.
con1: VDO mismatch: 0xff01a043 vs 0x00140045
```

The direct USB-C connection still re-attached four times in about 70 s:

```
08:29:34  UCSI_GET_PDOS failed (-70)
08:29:35  UCSI_GET_PDOS failed (-70)
08:29:35  con1: Firmware bug: duplicate partner altmode ...   <- re-attach
08:30:07  UCSI_GET_PDOS failed (-70)
08:30:08  con1: Firmware bug: duplicate partner altmode ...   <- re-attach
08:30:34  UCSI_GET_PDOS failed (-70)
08:30:36  con1: Firmware bug: duplicate partner altmode ...   <- re-attach
```

One more side effect: with the adapter attached, `port0-partner` registers
**no** altmodes at all. DP works anyway, because the PD firmware enters DP mode
itself. So the duplicate-altmode handling is cosmetic for this symptom.

### Try it

```sh
sudo apt install linux-oem-26.04     # pulls linux-image-7.0.0-1014-oem + headers
```

`1014` sorts above `34`, so GRUB (`GRUB_DEFAULT=0`) boots the OEM kernel by
default from then on. The dracut and DKMS hooks run as for any Ubuntu kernel
(ipu7 camera, v4l2loopback). After rebooting:

```sh
uname -r                                          # 7.0.0-1014-oem
systemctl --user start display-notify.service     # timestamp each connect/disconnect
journalctl -k -b | grep -E 'altmode|UCSI'         # does the warning change or go away?
~/dotfiles/scripts/watch-display-hotplug.sh       # full trace, same as 2026-09-11
```

Compare against the 2026-09-11 traces: does the partner still detach, and does
DP still take ~10 s?

### Reverse

Press **Esc** during boot (the GRUB menu is hidden, `GRUB_TIMEOUT=0`), then
*Advanced options for Ubuntu* → `7.0.0-34-generic`. To remove it:

```sh
sudo apt remove linux-oem-26.04 linux-image-oem-26.04 linux-headers-oem-26.04 \
                linux-image-7.0.0-1014-oem linux-modules-7.0.0-1014-oem \
                linux-main-modules-zfs-7.0.0-1014-oem linux-headers-7.0.0-1014-oem
```

Those are the 1014 dependency names (`apt-cache depends`). If a later OEM
version has been installed by then, check with `dpkg -l '*oem*'`.

## Cause: the battery charge current on the direct cable

### VERIFIED 2026-10-13 15:19-15:30 --- the controlled A/B

One session, one cable, one port, one PD contract, **one variable changed**: how
much current the EC pulls into the battery.

| Battery state | Draw | Window | Re-attaches | Rate |
|---|---|---|---|---|
| Parked (`pending-charge`, in-band) | 0.011 W | 14:13:05 - 15:19, **65 min** | **0** | 0 /min |
| Charging (`Trickle`, i.e. full rate) | **32.6 W** | 15:19 - 15:30, **11 min** | **3** | 0.27 /min |

```
15:19     charge starts (charge_types Custom -> Trickle; 2.698 A x 12.07 V)
15:24:10  re-attach #18
15:28:31  re-attach #19   (+4 min 21 s)
15:29:59  re-attach #20   (+1 min 28 s)
```

At the charging rate, 65 parked minutes should have produced ~18 events. It
produced **none**; the Poisson probability of that by chance is ~1e-6. This is
the clean experiment that 09:09 did not give --- there the quiet started ~5 min
*before* charging stopped, so nothing could be credited.

**What this rules out: the PD negotiation itself.** For the whole 65-minute quiet
window the contract was *live* --- `port0 [sink]`, AC online from
`ucsi-source-psy-USBC000:001` at 20 V / 4.5 A, the laptop running entirely off
the cable (3.4-4.6 W of battery discharge before the replug, 0.011 W after). A
negotiated, active, power-delivering contract is stable. Only current into the
battery breaks it.

**How to re-run it.** Park: `echo Custom | sudo tee …/charge_types` with capacity
above the stop threshold --- expect `Not charging`, `current_now` ~1000. Charge:
`echo Trickle` (or raise `charge_control_end_threshold`) --- expect `Charging`,
`current_now` ~2698000. Count with
`journalctl -b -k | grep -c 'duplicate partner altmode'`; ten minutes each way is
plenty.

### The negotiation theory it replaces

**Theorised, now superseded --- kept for the reasoning.** Over the monitor's USB-C input, the monitor also
charges the laptop, so they negotiate a power contract. Every re-attach above
comes right after `UCSI_GET_PDOS failed (-70)`: the laptop failing to read the
partner's power offers (PDOs). A broken negotiation normally ends in a PD
**hard reset**, which drops VBUS and detaches the whole partner. That would give
exactly a periodic full re-attach.

**Caveat on that evidence:** the stable HDMI adapter *also* logs
`GET_PDOS failed (-70)` on attach (2026-09-30 08:37:00-01), and it doesn't drop.
So the failure is part of every attach here, not proof of the cause. The better
discriminator is **which way power flows**. The laptop is the *source* for the
adapter (port0 `power_role=[source]`, on battery), and that link is stable. The
monitor is a *source* charging the laptop, and that link drops. The drops also
re-register the partner, which is a CC/PD-level detach, not a DP-link loss. A
marginal video signal would drop the picture, not the partner.

The 2026-09-11 hub also logged `GET_PDOS` failures (`-5`). Whether that hub was
passing power through to the laptop is **unknown**.

Tests, cheapest first. Change one thing at a time:

1. A different USB-C cable, full-featured and e-marked 5 A (video + 100 W).
2. The Dell charger plugged into another port *before* connecting the monitor.
3. USB-C charging off in the monitor's menu, if the 27U730A has that setting
   (not checked).
4. The other Thunderbolt port (typec port1).

To capture it, log power events next to the Type-C ones:

```sh
udevadm monitor --kernel --subsystem-match=typec --subsystem-match=power_supply \
  | ts '%T' | tee /var/tmp/usbc-power-$(date +%H%M).log     # ts: moreutils
```

**Likely way around it:** a **USB-C → DisplayPort cable**, if the monitor has a
DP input. It carries no charging, so there's no power negotiation, and all four
lanes go to DP, so 4K60 works. Charge from the Dell charger instead.

### 2026-09-30, boot at 08:48:58: the USB-C controller didn't answer at all

```
08:49:05 ucsi_acpi USBC000:00: con1: failed to get status
08:49:06 ucsi_acpi USBC000:00: error -ETIMEDOUT: PPM init failed
```

The PPM is the laptop's USB-C/PD controller firmware, as seen by the OS. It
timed out during init, so `/sys/class/typec/` stayed **empty** for the whole
boot. The kernel had no view of the ports, and every typec check above returns
nothing.

The 2026-09-11 VIA hub + RTL8153 still enumerated at 08:49:46 and stayed up
until 09:59:56 (70 min). Whether it drove the monitor then is unknown. A dock
connected at about 11:45 produced **no kernel events at all**: no USB, no
Thunderbolt device (only the host routers `0-0`, `1-0`), and no DP connector.
**Tests run on a boot like this aren't comparable. Power off fully (not a
reboot) and check `ls /sys/class/typec/` shows `port0..2` before testing.**

This is the strongest evidence yet that the **laptop's PD controller
firmware** is misbehaving. It also fits the bogus VDO: `0xff01a043` is
(nearly) identical across three different partner devices, so it most likely
comes from the laptop's side. **Theorised.**

## What to do about it

Nothing applied yet. Ranked, cheapest first.

### 1. Park the battery (free, works today, no hardware)

Keep the capacity inside the `Custom` window so the EC never starts a charge:

```
echo Custom | sudo tee /sys/class/power_supply/BAT0/charge_types
echo 50     | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold
echo 55     | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```

**Why this is stable rather than a decaying workaround:** while parked the
laptop runs entirely off the cable and the battery does not drain (0.011 W,
capacity unmoved for 66 min). Not draining means it never falls below the start
threshold, so it never triggers a charge. It stays put as long as you are
plugged in.

Costs: you undock at ~55%, not 100%. And the charging has to happen *somewhere*
--- roughly **6 minutes of flicker per 5%** at 32.6 W, whenever you do top up.
Not persistent across a reboot; see *Live changes* for the sysfs paths, and
`PrimAcUse` below for the BIOS-backed version.

### 1b. The toggle script

`scripts/charge-mode.sh` --- two states, nothing clever:

```
~/dotfiles/scripts/charge-mode.sh           # toggle
~/dotfiles/scripts/charge-mode.sh park      # Custom 50/55, don't charge
~/dotfiles/scripts/charge-mode.sh normal    # Fast 50/90, the factory setting
~/dotfiles/scripts/charge-mode.sh status    # just print
```

Prompts for sudo itself, prints before/after including actual watts, and warns
if you park below 55% (it charges up to 55 first, with drops, then parks).
**Not installed anywhere and not persistent** --- it writes `/sys` directly, so
it is only a command. Run `normal` before undocking if you want a full battery.

An earlier version of this section described a udev + systemd unit that switched
policy automatically by power source. **Deliberately dropped as over-built**
(2026-10-13) in favour of the two-state script.


### 2. Charge from a different port (user-confirmed working 2026-10-13)

Put the Dell charger (or any other PD source) on `port1`/`port2` and let the
monitor do **video only**. The charge current then never crosses the monitor's
cable. **The user confirmed both work simultaneously on 2026-10-13.** This is
separate evidence from the 13:05-13:33 charge, when the monitor was unplugged.
It is a workaround; single-cable operation remains the goal.

### 3. USB-C -> DisplayPort cable (the structural fix)

No PD on the video cable at all, so there is nothing to negotiate and no current
to carry. Charge separately. 4K60 8-bit needs ~12.5 Gbit/s; four lanes of HBR2
(DP 1.2) give ~17.3, so DP 1.2 suffices --- buy **DP 1.4 / HBR3 ("DP8K")** for
10-bit/HDR headroom. **Cost: no more single-cable docking.**

### 4. BIOS `PrimAcUse` (persistent version of #1)

`PrimaryBattChargeCfg = PrimAcUse` ("Primarily AC Use") caps the battery low and
sidesteps both the 50/55 floor and the reboot-persistence problem. See *Dell BIOS
configuration from Linux*. **Untested; semantics not confirmed against Dell docs.**

### Not a fix

- **The OEM kernel** --- tried 2026-09-28, drops unchanged.
- **`charge_types=Trickle`** --- cosmetic, still charges at 32.6 W. It is how the
  A/B above was *started*, not a way to charge gently.
- **The Type-C power-role swap** (`port0` to `source`) --- it works, but it means
  running on battery, which is not a fix so much as refusing to charge at all.

## Why the HDMI adapter is 4K30 only

The monitor's EDID as seen through the adapter (decoded from
`/sys/class/drm/card1-DP-1/edid`, 2026-09-30):

```
name: LG ULTRAFINE
HDMI Forum VSDB (HDMI 2.x), max TMDS 600 MHz     <- the input can do HDMI 2.0
range limits: vert 40-60 Hz, max pclk 600 MHz
VICs: [1, 3, 4, 16, 18, 31, 32, 34, 95, 95, 95, 94, 93]
DTDs: 3840x2160@30 (297 MHz), 2560x1440@59.95, 1920x1080@59.93
```

So sway is offered no `3840x2160@60`. The USB-C side isn't the limit: the
adapter gets 4 lanes (pin C). And the monitor isn't the limit either: **"HDMI
ULTRA HD Deep Colour" is already on** (checked 2026-09-30), and it advertises
600 MHz.

**VIC 95 (4K30) listed three times** is the fingerprint. A real EDID lists each
VIC once, and this list would normally have 97 (4K60) and 96 (4K50) where the
extra 95s sit. So the adapter most likely **rewrites the EDID** down to what its
HDMI chip can do (HDMI 1.4-class, 4K30), leaving the HDMI Forum block alone.
**Theorised.** To confirm, compare against another HDMI source on the same
monitor input. **This adapter can't give 4K60, so don't chase monitor settings
or kanshi modes for it.**

## The kernel options on this machine

As of 2026-09-28:

| Kernel | Base | Extra patches | Updates |
|---|---|---|---|
| `linux-generic-hwe-26.04` (running) | 7.0 (`7.0.0-34`) | Ubuntu SAUCE | yes |
| `linux-generic-hwe-26.04-edge` | same build, `7.0.0-34` | same | yes |
| `linux-oem-26.04` | 7.0 (`7.0.0-1014`) | Ubuntu SAUCE + OEM hardware-support fixes | yes |
| mainline (kernel.ubuntu.com) | 7.2.6 stable, 7.3-rc3 | **none**: upstream built with Ubuntu's config | **none** |

**Gotcha:** `ubuntu-drivers list-oem` prints **nothing** for this model (XPS 14
DA14260, SKU `0DB9`), and no `oem-*` metapackage is installed. That only means
Ubuntu doesn't *recommend* an OEM kernel here. `linux-oem-26.04` is still in
the archive and installs normally.

**The OEM kernel is not newer.** It's the same 7.0 base as the generic kernel,
plus backports. For a newer upstream version, mainline builds are the only
option.

### Testing a mainline kernel

Secure Boot is **disabled** (`mokutil --sb-state`), so the unsigned mainline
images boot without MOK enrolment.

```sh
mkdir -p ~/Downloads/kernel-7.2.6 && cd ~/Downloads/kernel-7.2.6
base=https://kernel.ubuntu.com/mainline/v7.2.6/amd64
v=7.2.6-070206; b=7.2.6-070206.202609141300
for f in linux-headers-${v}_${b}_all.deb \
         linux-headers-${v}-generic_${b}_amd64.deb \
         linux-image-unsigned-${v}-generic_${b}_amd64.deb \
         linux-modules-${v}-generic_${b}_amd64.deb; do
  wget "$base/$f"
done
sudo apt install ./linux-*.deb

# LUKS still unlocks only if dracut built a proper initrd. Check before rebooting:
sudo lsinitrd /boot/initrd.img-${v}-generic | grep -cE 'cryptsetup|dm-crypt'   # non-zero
dkms status
```

For another version, pick one from `https://kernel.ubuntu.com/mainline/` and
check that its page says `Test amd64/build succeeded`. (The amd64 *self-tests*
failed for 7.2.6. That's common and not about booting.)

Gotchas:

- **It becomes the default** as soon as it's installed (highest version, first
  GRUB entry). The way back is the Esc menu, as above.
- **Ubuntu kernel updates won't take over.** Future `7.0.0-3x` updates install
  but sort below it, so you keep booting mainline until it's removed.
- **No security updates**, and apt never upgrades or removes it.
- **DKMS may fail**, `ipu7-drivers` especially, which means no built-in camera
  on that kernel. The kernel still boots.
- **No SAUCE patches**, including the i915 DP-alt false-disconnect fix above.
  For *this* symptom, mainline can be worse than the generic kernel.

Remove:

```sh
sudo apt remove linux-image-unsigned-7.2.6-070206-generic linux-modules-7.2.6-070206-generic \
                linux-headers-7.2.6-070206-generic linux-headers-7.2.6-070206
```

**Optional (boot the test kernel once, then fall back automatically):** set
`GRUB_DEFAULT=saved`, `update-grub`, `grub-set-default` the 7.0 entry, then
`grub-reboot` the test entry. Get entry titles with
`sudo grep -E "^\s*(menuentry|submenu) '" /boot/grub/grub.cfg`. The catch: this
pins the default, so later Ubuntu kernel updates don't become the default
either.

## Where to read what a kernel fixed

- **Ubuntu kernels:** read the *source* changelog. Each entry has a
  `LP: #N` → `https://bugs.launchpad.net/bugs/N`.
  - OEM: `https://changelogs.ubuntu.com/changelogs/pool/main/l/linux-oem-7.0/linux-oem-7.0_<ver>/changelog`
  - generic: `https://changelogs.ubuntu.com/changelogs/pool/main/l/linux/linux_<ver>/changelog`
  - **Gotcha:** `apt changelog linux-image-7.0.0-1014-oem` returns the
    *`linux-signed-oem-7.0`* changelog, which is only packaging resyncs. It
    looks like the OEM kernel fixed nothing. Use the URL above instead.
- **Mainline:** `https://kernelnewbies.org/Linux_7_2` (per-release summary);
  `https://cdn.kernel.org/pub/linux/kernel/v7.x/ChangeLog-7.2.6` (a stable
  point release). For this symptom, the relevant directories to
  `git log v7.0..v7.2 --` are `drivers/usb/typec/ucsi` and
  `drivers/gpu/drm/i915/display`.

## Firmware

`fwupdmgr get-updates` on 2026-09-28: **no updates**. System Firmware is at the
latest LVFS version (BIOS 1.11.0, up from 1.9.0 on 2026-09-11). The "please
update your system firmware" warning is still there after that update, so a BIOS
update is not currently an option. Check Dell's support page for release notes
too, since not every Dell BIOS lands on LVFS immediately.

## Tooling already in the repo

- `scripts/watch-display-hotplug.sh`: logs Type-C partner/altmode + DRM
  connector state and kernel lines to `/var/tmp` (it survives a compositor crash).
  No root needed.
- `scripts/capture-display-state.sh`: a snapshot while the monitor is connected.
- `sudo scripts/debug-display-verbose.sh`: dynamic debug for UCSI/Type-C/TBT
  plus `drm.debug`, restored on exit. Loud.
- `systemd/user/display-notify.service` → `scripts/notify-display-connect.sh`:
  a mako notification on each connector change. Symlinked by `symlinkifier.pl`,
  but it was **inactive** on 2026-09-28, so today's drops weren't timestamped.
- **Gotcha** (from the watch script): don't press **F9** (`toggle-display.sh`)
  during an unplug. It raced the teardown and segfaulted sway once.

## Live changes made 2026-10-13 — and how to revert them

**Status at 15:32: `Custom` + `50/55` is applied *deliberately*** --- it is
workaround #1 from *What to do about it*, not a leftover test artefact. The
power-role swap is **gone** (a replug at 14:13 put `port0` back to `[sink]` on
its own). All of these are runtime writes to `/sys`; none is tracked by this repo
and none was added to `symlinkifier.pl`.

### Original values, captured before anything was touched (09:01)

| Path | Original | Now (15:32) | Why |
|---|---|---|---|
| `/sys/class/power_supply/BAT0/charge_types` | `Fast` | **`Custom`** | deliberate --- parks the battery |
| `/sys/class/power_supply/BAT0/charge_control_start_threshold` | `50` | `50` | unchanged |
| `/sys/class/power_supply/BAT0/charge_control_end_threshold` | `90` | **`55`** | deliberate --- parks the battery |
| `/sys/class/typec/port0/power_role` | `sink` | `sink` | reverted itself at the 14:13 replug |

Verified parked at 15:32: `Not charging`, 62%, `current_now = 1000`, `AC online = 1`.

`port1` and `port2` read `[source]` after the morning swap. **Not established**
whether that was a side effect of the port0 swap or a wider change --- check all
three if you revert.

### Revert --- only if you want full-rate charging back

This undoes the workaround, so **expect the re-attaches to return** whenever the
battery is below 90%.

```
echo Fast | sudo tee /sys/class/power_supply/BAT0/charge_types
echo 50   | sudo tee /sys/class/power_supply/BAT0/charge_control_start_threshold
echo 90   | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
for p in 0 1 2; do echo sink | sudo tee /sys/class/typec/port$p/power_role; done
```

Then confirm — **do not trust the setting, measure it** (see the no-op gotcha
below):

```
cat /sys/class/power_supply/BAT0/charge_types          # want [Fast]
cat /sys/class/power_supply/BAT0/current_now           # want ~2700000 when charging
cat /sys/class/power_supply/AC/online                  # want 1 with a charger in
for p in 0 1 2; do cat /sys/class/typec/port$p/power_role; done   # want [sink]
```

A reboot probably clears `power_role` (it is renegotiated per attach) but
**probably does not clear the charge settings**, which are backed by a BIOS
policy. Don't rely on a reboot; set them back explicitly.

### Gotcha: the thresholds work, the rate selector does not

Two different knobs with two different answers. The original claim in this file
--- "both are accepted by sysfs and ignored by the EC" --- was half wrong, and
the first correction (2026-10-13 15:00, "they only apply to the next cycle")
over-generalised the fix to both. Settled 2026-10-13 15:20:

- **`charge_control_start/end_threshold` really work**, but only from a fresh
  cycle. Writing them mid-charge does nothing, which is what produced the
  original wrong conclusion.
- **`charge_types` is cosmetic as a *rate*.** Selecting `Trickle` is accepted and
  reads back `[Trickle]`, but the battery charges at full rate anyway. Measured
  twice, once mid-charge and once from a cold start, with the same result:
  **32.8 W** (2.70 A x 12.14 V) and **32.6 W** (2.698 A x 12.07 V). There is no
  slow-charge mode reachable from sysfs here.
- **`charge_types` also selects which policy is live**, so putting it in
  `Trickle` takes you out of `Custom` and the `50/55` window stops gating. The
  battery then charges past the stop threshold toward full. `echo Custom` to get
  the window back.

The mid-charge evidence (both knobs written while a charge was already running):

- With `charge_types = [Trickle]`: battery took **2.70 A x 12.14 V = 32.8 W**,
  48% -> 51% in three minutes. That is full-rate charging.
- With `charge_types = [Custom]`, window `50/55`, battery **at 55%** (i.e. at the
  stop threshold): still `Charging` at **2698000 uA**.

The threshold on the next *fresh* cycle, same settings untouched, charger on a
different port (from `/var/lib/upower/history-{charge,rate}-DELL_*.dat`):

```
13:05:25   31%  charging    30.793 W     <- charge begins
13:33:27   55%  charging    30.931 W     <- reaches the stop threshold
13:34:44   55%  pending-charge  0.011 W  <- EC cuts it. The knob works.
13:54:28   54%  discharging              <- charger unplugged
```

And the start threshold holds too: at 15:03, AC online from the monitor and the
battery at **52%**, `status = Not charging`, `current_now = 1000` (1 mA). 52% is
inside the `50..55` band, so the EC will not re-start until it falls below 50.

So the rule is: **for the thresholds, write the knob and then let the charge stop
and restart** --- writing during a charge does nothing and looks like the setting
was ignored. **For the rate, there is no rule; it cannot be changed.** Either way,
**check `BAT0/current_now`** before believing a charge setting took. That part of
the original gotcha was right, and it is what caught both failures.

`status = Not charging` with `AC online = 1` is the healthy in-band state, and is
different from `Discharging` (no AC at all) --- which is what the Type-C
power-role swap produced.

### Gotcha: the charge window cannot go below 50/55

The BIOS caps it. From `dell-wmi-sysman`:

```
CustomChargeStart   integer   50..95
CustomChargeStop    integer   55..100
```

So "set the window below the current charge level to stop charging now" only
works if the battery is **above 55%**. Advice to use e.g. 30/35 is impossible on
this hardware.

### The real control surface: BIOS attributes, not `power_supply`

`dell_wmi_sysman` is loaded and exposes the actual BIOS settings at
`/sys/class/firmware-attributes/dell-wmi-sysman/attributes/`, including
`PrimaryBattChargeCfg` (`Adaptive;Standard;Express;PrimAcUse;Custom`),
`CustomChargeStart`, `CustomChargeStop`, `AdvBatteryChargeCfg`, plus
`UsbPortsExternal`, `ThunderboltPorts` and `DisUsb4Pcie`. Writing these changes
the firmware setting itself, which is almost certainly why the
`power_supply` knobs lose — something upstream of them is in charge.

`current_value` is **root-read-only**, so a non-root `cat` returns empty rather
than erroring — that looks like "no value set" and is not.
`authentication/Admin/is_enabled` is `0`, so no BIOS admin password is in the
way. **Untested: whether writing these actually sticks.**

### Is there a GUI?

Not really, in this order of usefulness:

- **BIOS setup (F2 at boot) -> Battery Charge Configuration** — the authoritative
  place, and the one guaranteed to work. The GRUB menu is hidden, so **Esc at
  boot** to reach it.
- **`gnome-control-center power`** is installed (1:50.3) and runs fine under
  Sway. Its charge-limit toggle drives `charge_control_end_threshold` — **the
  knob that is ignored here**, so expect it not to work.
- **TLP** (`apt install tlp`, 1.8.0 in the archive) is the normal way to make
  thresholds *persist* via `START_CHARGE_THRESH_BAT0` /
  `STOP_CHARGE_THRESH_BAT0`. Config file, not a GUI; **TLPUI is not in the Ubuntu
  archive**. Same caveat: it writes the same ignored sysfs paths.
- `dell-command-configure` / `cctk` (Dell's own tool) is **not installed** and
  not in the archive.

## Dell BIOS configuration from Linux (`dell-wmi-sysman`)

Researched 2026-10-13. **Nothing here has been applied or written** — values below
are `default_value`, not necessarily what the machine is set to.

`dell_wmi_sysman` is loaded and exposes the real BIOS settings at
`/sys/class/firmware-attributes/dell-wmi-sysman/attributes/<Name>/`. **This, not
`/sys/class/power_supply/BAT0/`, is the control surface that actually owns
charging policy** — which is the likely reason the `charge_types` and threshold
writes were no-ops (see the gotcha above).

### Why the power_supply knobs probably lose

`PrimaryBattChargeCfg` defaults to **`Adaptive`**. The 2024 `dell-laptop` kernel
patch that added the charge knobs notes that Linux's charge-threshold settings
drive the **Custom** mode specifically. So `charge_control_*` plausibly only bites
when the *BIOS* policy is already `Custom`, and writing
`power_supply/BAT0/charge_types` does not necessarily flip the BIOS attribute.
**Theorised, not verified** — but it fits the measurements exactly.

| `PrimaryBattChargeCfg` | Behaviour |
|---|---|
| `Adaptive` (**default**) | Learns usage; XPS ships this way. Reportedly flips to Primary AC mode after ~12 h plugged in |
| `Standard` | Charges to 100%, <=3 h |
| `Express` | Rapid charge. **Sources conflict**: Dell says 80% in ~1 h, Notebookcheck says 100% in <=2 h |
| `PrimAcUse` (= BIOS "Primarily AC Use") | Caps charge to extend lifespan. **Sources conflict**: Dell says 50-80%, Notebookcheck says ~80% via a Charge Limiter + Learn Mode |
| `Custom` | Uses `CustomChargeStart` / `CustomChargeStop` |

For capping charge, **`PrimAcUse` is simpler than `Custom`** — no thresholds to set,
and it sidesteps the 50/55 floor entirely.

### How to write an attribute

```
echo PrimAcUse | sudo tee \
  /sys/class/firmware-attributes/dell-wmi-sysman/attributes/PrimaryBattChargeCfg/current_value
cat /sys/class/firmware-attributes/dell-wmi-sysman/attributes/pending_reboot
```

- **No BIOS admin password is set here** (`authentication/Admin/is_enabled` = `0`),
  so the `current_password` dance is not needed. With one set, every write needs the
  password written first and cleared after; writes fail `-EOPNOTSUPP` with no
  password and `-EACCES` with the wrong one.
- `pending_reboot` reads **`0`** and is world-readable. If a write flips it to `1`,
  the change needs a reboot to take.
- `dell_value_modifier` can force an attribute's value from another setting. It is
  **empty** on every attribute checked here, so nothing is overriding.
- **Gotcha:** `current_value` is root-read-only and a non-root `cat` returns
  **empty, not an error** — that reads as "unset" and is not. `default_value`,
  `possible_values` and `display_name` are all world-readable.

### USB-C / Thunderbolt attributes this BIOS exposes

| Attribute | BIOS name | `default_value` |
|---|---|---|
| `VideoPowerOnlyPorts` | Video/Power only on Type-C Ports | **Disabled** |
| `TypeCDockOverride` | Type-C Dock Override | Enabled |
| `TypeCDockLan` | Type C Dock Lan | Enabled |
| `ThunderboltPorts` | Enable Thunderbolt Technology Support | Enabled |
| `ThunderboltBoot` | Enable Thunderbolt Boot Support | Disabled |
| `DisUsb4Pcie` | Disable USB4 PCIE Tunneling | Disabled |
| `UsbPortsExternal` | Enable External USB Ports | Enabled |

`VideoPowerOnlyPorts` is the tempting one — the monitor's USB hub isn't used on
this connection anyway, so dropping USB data would cost nothing. **But its exact
semantics could not be confirmed from Dell's documentation**, and whether it
touches PD renegotiation at all is speculation. Treat it as an experiment, not a fix.

### Supporting finding

Plugable's write-up on USB-C problems in Dell XPS/Precision says the instability
"primarily affects transmission of USB data packets" and that DP Alt Mode video
"seems much less likely to be impacted." **That is exactly the shape seen here** —
DP holds 4K60 while the USB/PD layer churns. It's a known failure mode for this
hardware family, not something specific to this monitor.

**No source documents this exact symptom on an XPS.** Dell's own advice is generic:
update BIOS and Thunderbolt firmware, confirm the Type-C controller is enabled and
Port Disable isn't set, try Load Defaults. BIOS 1.9.0 is current (`fwupdmgr`,
checked 2026-09-28).

### Sources

- Notebookcheck, *Dell XPS features more battery charging options than most other laptops* — <https://www.notebookcheck.net/Dell-XPS-features-more-battery-charging-options-than-most-other-laptops.1271714.0.html>
- Dell KB 000125125, *How to Troubleshoot AC Adapter Issues on a Dell Laptop* — <https://www.dell.com/support/kbdoc/en-lk/000125125>
- LKML, *dell-laptop: Add knobs to change battery charge settings* (2024) — <https://lkml.iu.edu/hypermail/linux/kernel/2407.2/04480.html>
- LKML, *Systems Management Driver over WMI for Dell Systems* — <https://lkml.rescloud.iu.edu/hypermail/linux/kernel/2009.2/07019.html>
- Plugable, *A Closer Look at USB-C Problems on Some Dell XPS and Precision Laptops* — <https://kb.plugable.com/en_US/general-support-articles/a-closer-look-at-usb-c-problems-on-some-dell-xps-and-precision-laptops>
- Dell KB 000124220, *Dell USB-C and Thunderbolt docks: BIOS settings and driver installation* — <https://www.dell.com/support/kbdoc/en-us/000124220>

## History

What was connected, when, and what happened. Times are local. "Re-attach" =
a new `con1: Firmware bug: duplicate partner altmode` line, which the kernel logs
on every partner attach. **Count them with
`journalctl -k -b | grep -c 'duplicate partner altmode'`.** A rising count with
nobody touching the cables means a drop.

| Date | Kernel | Connection | Result |
|---|---|---|---|
| 2026-09-11 | 7.0.0-31-generic, BIOS 1.9.0 | VIA hub on port2 (non-TB) | Partner detached every ~15-30 s while being traced. Some of that was deliberate replugging for the test. DP took ~10 s to come up when it did |
| 2026-09-28 | → 7.0.0-1014-oem | (install only, 15:18) | — |
| 2026-09-30 08:29 | 7.0.0-1014-oem | monitor's USB-C, direct, port0 | **4 re-attaches in ~70 s.** Abandoned after that, so it's unknown whether it would have settled. Battery level not recorded (no UPower history that day) |
| 2026-09-30 08:37 | 7.0.0-1014-oem | no-name HDMI adapter `343c:0000`, port0 | Stable, **4K30 max**. One USB disconnect at 08:38:13 (back 3 s later), cause unknown |
| 2026-09-30 08:48 boot | 7.0.0-1014-oem | — | **`PPM init failed`**: `/sys/class/typec/` empty all boot (see above). Tests on this boot aren't comparable |
| 2026-09-30 08:49 | same boot | VIA hub | Up until 09:59:56, no drops (70 min). Whether it drove the monitor then is unknown |
| 2026-09-30 11:48 | same boot | **ThinkPad Thunderbolt 3 Dock (40AN)** on a TB port, own power brick | **4K60** (`DP-6`). Charging the laptop (AC=1, though BAT read "Discharging"). TB link 2 × 10 Gb/s. Disconnected 11:51:46 after 3.5 min; **whether that was a manual unplug is unknown** |
| 2026-09-30 11:53 | same boot | VIA hub | Dropped 11:54:26 (31 s in), back 11:54:29, then stable until 13:37:16. Cause of the 11:54:26 drop unknown. **4K30 max** through this hub (`rates@4K=[23..30]`) |
| 2026-10-12 09:02 boot | **7.0.0-1015-oem** | — | USB-C controller up normally (`port0..2` present) |
| 2026-10-12 09:02 | same boot | VIA hub, port0 | Disconnects at 09:03:22 and 09:04:07 were **manual replugs** (user, 2026-10-12). Then stable 09:04:27 → 13:47:02 (4 h 43 min, unplugged by hand) |
| 2026-10-12 13:47:22 | same boot | **monitor's USB-C, direct, port0** | **4K @ 59.997 Hz.** The monitor charges the laptop: port0 `power_role=source [sink]`, `ucsi-source-psy-USBC000:001` online, 15 V, Imax 4.5 A. **No drops through 13:53:31** (count = 4: three hub attaches + this one). **User will report back if it drops.** |
| 2026-10-13 08:58 boot | 7.0.0-1015-oem | **monitor's USB-C, direct, port0 (con1)** | **It does drop** — answering the 2026-10-12 open question. DP-1 holds 3840x2160 @ 59.997 Hz and the picture stays up, but **11 re-attaches in the first 6 minutes** (3/2/1/1/1/3 per minute across 08:58-09:03). **Sustained ~1-3/min, not tapering** — an apparent lull at 09:01 was a measurement artefact of a too-short window, so give it 10 min before calling it settled. Monitor charges the laptop: port0 `source [sink]`, 20 V / 4.5 A, battery 48% and **fast-charging** (`charge_types=Fast`). Consistent with the charging theory, does not prove it. **Gotcha: the monitor's USB hub is not attached on this connection** (zero USB disconnects in 24 h), so `grep -c '0bda:5411'` counts **nothing** and looks like success — count `duplicate partner altmode` instead. **Outcome: it went quiet at 09:09:21 and stayed quiet** — 16 re-attaches total for the boot, none after 09:09, still clean at 09:24 (15 min). A measured 10-min window with charging genuinely off (09:14:28 onward, `AC=0`/`Discharging`) gave **0 re-attaches against a ~15-20 baseline**. **But the quiet started ~5 min BEFORE charging stopped**, while the battery was still taking 32.9 W — so the power-role swap cannot be credited with starting it, only with holding it. **The charging theory is still not confirmed.** The test that settles it: put `port0` back to `sink`, let it charge, and see if bursts return within ~10 min. **Shape of the fault: bursty, not periodic** — a 5-min watch (09:02:53-09:07:53) caught 5 re-attaches as 09:03:53 / +28 s / +17 s, then **2 min 43 s of quiet**, then +17 s. Unlike the old UltraFine's rigid 15 s-up / 2.3 s-down metronome, so don't expect a fixed interval. Also **6 `GET_PDOS failed (-70)` for 5 re-attaches** — a GET_PDOS failure can occur without a re-attach, independently confirming it isn't the trigger. **`charge_types=Trickle` is a no-op here**: sysfs accepts it and reports `[Trickle]`, but the battery kept taking **2.70 A x 12.14 V = 32.8 W** (48%->51% in 3 min). The charging theory was *not* tested by it. Verify `BAT0/current_now` before believing any charge knob |
| 2026-10-13 14:13 replug | 7.0.0-1015-oem | **monitor's USB-C, direct, port0 (con1)** | **50 minutes clean and counting** (14:13:05 -> 15:03, DP-1 at 3840x2160 @ 59.997). 17 re-attaches for the boot; the 17th *is* the replug itself, so **zero unprompted drops**. `port0` is back to `[sink]` on its own (the replug reverted this morning's power-role swap), and AC is online from `ucsi-source-psy-USBC000:001` at 20 V / 4.5 A --- so **the PD contract is up, the laptop is a sink, and nothing is dropping.** What is *not* happening is charge current: battery 52%, `Not charging`, `current_now = 1000` (1 mA), because 52% sits inside the `50..55` Custom window. **This narrows the charging theory from "the PD negotiation" to "the charge current"** --- the negotiation is live right now and stable. Not yet decisive: the battery has to fall below 50% (or the stop threshold be raised) for the EC to pull real current through the monitor cable. **Does not count as evidence: the 13:05-13:33 charge** (31% -> 55% at ~31 W) was from a charger on a *different port* with the monitor unplugged (display-change hook ran 13:00:01, next at 14:13:13), so it says nothing about the display. It did, however, **disprove the "charge knobs are no-ops" gotcha** --- the 55% stop fired cleanly at 13:34:44 (`pending-charge`, 0.011 W). See the corrected gotcha above |
| 2026-10-13 15:19 A/B | 7.0.0-1015-oem | **monitor's USB-C, direct, port0 (con1)** | **Cause found. The charge current, not the PD negotiation.** Controlled A/B in one session, one cable, one port, one live PD contract, only the charge current changed. **Parked** (`pending-charge`, 52%, in-band on the `50/55` window, 0.011 W): 14:13:05-15:19, **65 min, 0 re-attaches**. **Charging** (2.698 A x 12.07 V = **32.6 W**): 15:19-15:30, **11 min, 3 re-attaches** --- 15:24:10, 15:28:31 (+4m21), 15:29:59 (+1m28), felt as picture loss at the desk. 0.27/min charging vs 0/min parked; 65 parked minutes should have given ~18 events, Poisson p ~1e-6. **Rules out the negotiation**: throughout the quiet window the contract was live and delivering (20 V / 4.5 A, `port0 [sink]`, battery discharge 3.4-4.6 W before the replug vs 0.011 W after --- the cable carried the whole system load). **Started with `charge_types=Trickle`, which is cosmetic** --- it charges at full rate and *also* drops you out of `Custom`, so the window stops gating and it ran 52% -> 61% straight past the 55% stop. See *What to do about it* |

Latest follow-up:

| Date | Kernel | Connection | Result |
|---|---|---|---|
| 2026-10-13 15:45:55 targeted trace | 7.0.0-1015-oem, BIOS 1.11.0 | Monitor's USB-C, direct, port0; no replug | Parked until `Trickle` write at 15:51:41; battery verified charging at 32.9 W. Interruptions 15:52:14–15 and 15:52:43–44. Both captured as firmware-disconnected → source → sink. `Custom` restored 15:52:51; BAT0 verified stopped at 15:53:30. See targeted trace section for raw events and limitations. |
| 2026-11-02 09:42 | 7.0.0-1017-oem | **USB-C → DisplayPort cable, port0** (laptop is the power source, nothing to negotiate). **The laptop charges from a separate charger on another USB-C port** | Rest of the boot (to 16:13, about 6.5 h): **0 `Destroying output DP-1`**. One `duplicate partner altmode` line at attach (09:42:44), none afterwards. Link HBR2 × 4 lanes (see `docs/hdr-on-external-monitor.md`). 26 `Page-flip failed on output DP-1` (EBUSY), each a single line |
| 2026-11-03 08:54 boot | 7.0.0-1017-oem | DP cable, port0; charger on another port | Up from boot until 10:02:34 (68 min), **0 faults**. DP-1 went away at 10:02:34 and **didn't come back that boot**, so it was an unplug, not a fault |
| 2026-11-05 08:37 boot | 7.0.0-1017-oem | DP cable, port0. Charger on **port2** (`ucsi-source-psy-USBC000:003`, 15 V / 3 A); port0 and port1 `[source]` (port1 is the Voyager) | **0 display losses** as of 09:28 (50 min), while the battery was **charging at 2.7 A on `Fast`**, the condition that set off bursts on the monitor's USB-C cable. 3 `Page-flip failed on output DP-1` (09:11:21, 09:11:28, 09:19:39). The user asked "did my screen just go out?" at 09:27, but nothing was logged. **Unexplained** whether the page-flips are visible or what the user saw |

Caveats on the 2026-10-12 result, so it isn't over-read as a fix:

- **Only ~6 minutes observed**, against 4 drops in 70 s on 2026-09-30.
- **The battery was full.** UPower: 98% at 13:47:06, `fully-charged` at
  13:47:23. A full laptop draws little from the monitor. If the drops are a
  charging problem, the real test is reconnecting with the battery well below
  full.
- **Two things differ from 2026-09-30:** kernel 1015 instead of 1014, and the
  USB-C controller initialised normally this boot. BIOS is unchanged (1.11.0).
  The only change in 1015 in this area is `SAUCE: drm/i915/tc: Revert forced
  DP-alt connected workaround` (LP: #2160082, *"System hangs for about 10 seconds
  when unplug external monitor cable on non TBT dock"*), plus a re-sync of the
  UCSI duplicate-altmode patch. Neither obviously explains PD-level re-attaches.

## Open

- **Superseded in practice since 2026-11-02:** the user runs a USB-C →
  DisplayPort cable and charges from a separate port, which has had 0 display
  losses in about 8.5 h docked (see *History*). Single-cable docking is
  still broken; this is a way around it, not a fix.

- What causes the firmware-reported disconnects captured on 2026-10-13:
  monitor power supply, cable/contact under load, Dell controller behaviour,
  or interoperability. Windows also fails; separate-port charging works
  (user-confirmed). See the targeted trace section for scope and limitations.
- Why command events are absent from the `ucsi:*` capture; capture those before
  concluding whether Linux requested a reset.
- Whether the charge current breaks the link at every rate or only near full
  rate. Only 0 W and 32.6 W have been measured --- there is no middle setting
  reachable from sysfs (`Trickle` is cosmetic), so this needs a current-limited
  PD source to answer.
- Reconcile the earlier 15:31:25 current-stop timestamp with the sudo journal:
  the user's Custom write was **15:31:38**, after the 15:31:27 warning.
  Do not attribute that warning to this later command.
- Whether the ThinkPad dock's disconnect at 2026-09-30 11:51:46 was manual.
- Whether the 27U730A has a DisplayPort input.
- Whether the adapter's one USB disconnect at 2026-09-30 08:38:13 (back 3 s
  later) was a manual replug.
- Why the bogus VDO is (nearly) identical across three different devices.
  Unexplained.

## Dead ends

| Tried | Date | Result |
|---|---|---|
| OEM kernel `7.0.0-1014-oem` (corrected UCSI duplicate-altmode patches) | 2026-09-28 | drops unchanged; the warning's wording changed, so the patch is live |
| BIOS update | 2026-09-28 | none available (`fwupdmgr`, 1.11.0 is latest) |
| Monitor "HDMI ULTRA HD Deep Colour" for 4K60 over the adapter | 2026-09-30 | already on; EDID through the adapter still has no 4K60 |
