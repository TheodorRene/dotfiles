# Handoff: the external display drops and re-attaches, cause not found

**Status: UNRESOLVED as of 2026-10-23.** Nothing applied that fixes it. This is a
briefing for a fresh investigator with kernel-source access. The long-form history
is `docs/usb-c-displays-disconnect-and-kernel-options.md` (953 lines); this file is
the distilled state of play, including two conclusions reached earlier that the
latest data **contradicts**.

---

## 1. The system

| | |
|---|---|
| Machine | Dell XPS 14 `DA14260` |
| BIOS | 1.11.0 (2026-08-04) — latest, `fwupdmgr` has nothing newer |
| OS | Ubuntu 26.04.1 LTS, Wayland, sway + kanshi |
| Kernel | `7.0.0-1015-oem` (`linux-oem-26.04`) |
| GPU | Intel Panther Lake **Arc B390** `[8086:b080]` rev 04, **integrated, no dGPU** |
| DRM driver | **`xe`** (not i915), `card1`, DP-1 at `/sys/devices/pci0000:00/0000:00:02.0/drm/card1/card1-DP-1` |
| PD controller | `ucsi_acpi USBC000:00`, connectors con1/con2/con3 = `typec` port0/port1/port2 |
| Monitor | **LG 27U730A**, 4K60 over USB-C DP alt mode, on **port0 / con1** |
| Monitor's hub | Realtek **RTS5411** `0bda:5411`, appears as `usb 3-2` |
| Modules | `ucsi_acpi`, `typec_ucsi`, `typec`, `typec_displayport`, `dell_wmi_sysman` |

The monitor is the **only** 4K60-capable path. A USB-C→HDMI adapter works but is
capped at 4K30 (the adapter rewrites EDID to VIC 95; not a monitor limitation).
There is **no HDMI connector on the laptop** — DRM exposes only `DP-1..3` + `eDP-1`.

**What the user wants:** single-cable docking — 4K60 video and charging over the
monitor's USB-C cable, without the picture dropping.

---

## 2. The symptom

The DRM connector `DP-1` goes `connected` → gone → `connected`. sway destroys and
recreates the output; kanshi re-applies a profile each time, which reshuffles
workspaces. The *reshuffle* is a config annoyance, not the fault — ignore it
(section 7).

**Bursty, never periodic.** On 2026-10-23: 23 display losses across the day, in
clusters, with quiet gaps of over two hours between them.

### Kernel signature

Three lines, usually as a group, on the PD side:

```
ucsi_acpi USBC000:00: UCSI_GET_PDOS failed (-70)
ucsi_acpi USBC000:00: con1: Firmware bug: duplicate partner altmode SVID 0xff01 at offset 1, ignoring but please contact the BIOS vendor to fix this issue.
ucsi_acpi USBC000:00: con1: VDO mismatch: 0xff01a043 vs 0x00140045
```

`-70` is `EREMOTEIO`; `-95` (`EOPNOTSUPP`) also occurs. A rejected `SET_PDR`
(power-role swap) logs `ucsi_acpi USBC000:00: unknown error 0`.

### The thing that matters most

**The DRM connector drop logs NOTHING.** No `xe`, no `drm`, no `i915` message at
default verbosity — the connector simply goes away and comes back. Every error
line above is from the UCSI/PD layer, and section 4 shows those are *not* the
trigger. **Instrumenting the DP/HPD path is the single highest-value next step.**

---

## 3. Measurement traps (each one cost a wrong conclusion)

1. **Do not count `duplicate partner altmode` as "the fault".** It is the PD
   re-attach, which follows the display loss (section 4). All measurements before
   2026-10-23 counted this and therefore measured the echo.
   Count instead: `journalctl -b | grep -c 'Destroying output DP-1'`.
2. **`grep -c '0bda:5411'` can read 0 and look like success.** The monitor's hub is
   sometimes not attached at all (it was absent for the whole 2026-10-13 session).
3. **The fault is bursty.** A 2m43s lull occurred *mid-burst*. Ten quiet minutes is
   the minimum bar; given 2h+ gaps on 2026-10-23, hours are better.
3b. **Classify every display loss by how long the output stayed gone.** 1-2 s is a
   fault; minutes means the user unplugged for a meeting. Counting unplugs as
   faults produced a bogus two-mechanism theory once already.
4. **Check `BAT0/current_now`, never a charge knob's own readback** (section 6).
5. **`current_value` under `dell-wmi-sysman` is mode 0600.** A non-root `cat`
   returns *empty*, which is not "unset".
6. **`pending_reboot` lives at `attributes/pending_reboot`**, not at the class root.

---

## 4. The 2026-10-23 finding that reframes everything

A merged timeline over one 7-hour boot: display-loss events from the session log,
PD and USB events from the kernel log.

### First, the correction that makes the data usable

The user was undocked for meetings three times. Those look identical to a fault in
the logs unless you measure **how long the output stayed gone**:

```
11:00:18  gone -> back 11:23:21   (23 min)   <- undocked, not a fault
12:39:07  gone -> back 13:19:34   (40 min)   <- undocked, not a fault
13:22:01  gone -> back 13:58:33   (36 min)   <- undocked, not a fault
every other loss:                 1-2 s      <- real faults
```

**Always classify by gap length before counting anything.** An earlier version of
this file built a whole "two distinct failure patterns" hypothesis out of these
three unplugs. It was wrong and has been removed.

### The real numbers

**20 real faults** and 3 unplugs. The accounting closes exactly:

```
24 PD_REATTACH  =  20 faults  +  4 redock/boot plug events
```

- **Every real fault has exactly one PD re-attach**, 1–3 s *after* the display loss.
- **Every PD re-attach without a display loss is a plug event** (08:51:56, 11:23:22,
  13:19:35, 13:58:34).
- **Every display loss without a PD re-attach is an unplug** (the three above).

So the shape is uniform — one mechanism, not two:

```
15:10:40  DISPLAY_LOST
15:10:42  PD_GETPDOS_FAIL      (+2 s)
15:10:43  PD_REATTACH          (+3 s)
          display back by itself 1-2 s after the loss
```

Within a burst the spacing is ~13–17 s; bursts are separated by minutes to hours.
Faults occurred at 08:53:02 and 08:53:30 (right after the morning dock, possibly
settling) and then 18 times between 15:10:40 and 15:41:58.

### What follows

- **The PD re-attach does not cause the display loss.** It arrives 1–3 s *after*,
  in all 20 cases.
- **The monitor's USB hub is not involved.** `usb 3-2` last enumerated at 12:39:09
  and is **absent now** — it failed to come back at the 13:19 and 13:58 redocks. All
  18 afternoon faults happened with no hub attached. (Separate the hub `3-2` from
  the Voyager keyboard `3-1`; conflating them is easy and misleading.)
- **So the fault is in the video link**, with PD reacting to it.

## 5. What is ruled out, with the evidence

| Ruled out | Evidence |
|---|---|
| **The OEM kernel's UCSI patches** | `7.0.0-1014-oem` (2026-09-28) carries the corrected duplicate-altmode patches (LP: #2162695). The warning's wording changed, so the patch is live; drops continued unchanged. |
| **`duplicate partner altmode` being the fault** | It is cosmetic — DP comes up even when no altmode registers — and it *follows* the display loss (section 4). |
| **`UCSI_GET_PDOS failed (-70)` being the trigger** | Occurs on *every* attach including the stable HDMI adapter that never drops; 32 failures for 24 re-attaches, so it fires without a re-attach too. |
| **The PD power negotiation** | On 2026-10-13 the contract was live and *delivering* (20 V / 4.5 A, `port0 [sink]`, battery discharge 3.4–4.6 W before the replug vs 0.011 W after — the cable carried the entire system load) for **65 minutes with zero drops**. An active, power-delivering contract is stable. |
| **`charge_types=Trickle` as a low-current mode** | Cosmetic as a rate: charges at 32.6–32.8 W regardless. It maps to Dell **Primarily AC Use** (`BAT_PRI_AC_MODE_TOKEN` in `dell-laptop.c`), not a current limit. |
| **A dGPU-related BIOS path** | There is no dGPU. Single integrated Arc B390; DP-1 hangs off `00:02.0`. |

---

## 6. The charge-current result — real, but NOT the mechanism

On **2026-10-13** a controlled A/B (one session, one cable, one port, one live PD
contract, only the charge current varied):

| Battery | Draw | Window | Display/PD events |
|---|---|---|---|
| Parked (`pending-charge`, in-band) | 0.011 W | 65 min | **0** |
| Charging (full rate) | **32.6 W** | 11 min | **3** |

~18 events were expected in the parked window at the charging rate; Poisson
p ≈ 1e-6. **This result is sound and reproducible** — charge current massively
raises the rate.

**But it is not necessary.** On 2026-10-19 and again all of 2026-10-23 the drops
occurred with the battery **parked at 0.0 W** (`Not charging`, `current_now = 1000`,
no upower rate samples at all). So charge current is an *aggravating factor*, not
the cause. Any model reading the older write-up will find a "CAUSE FOUND" claim —
**that claim is too strong and is superseded by this file.**

### Charge-knob semantics (hard-won, keep)

- `charge_control_start/end_threshold` **work**, but only from a *fresh* cycle.
  Written mid-charge they do nothing — which produced an earlier wrong
  "the EC ignores them" conclusion.
- `charge_types` is a **mode selector**, not a rate. Setting `Trickle` also drops
  you out of `Custom`, so the window stops gating.
- BIOS floor: `CustomChargeStart` 50..95, `CustomChargeStop` 55..100.
- `Not charging` + `AC online=1` is the healthy parked state; `Discharging` means
  no AC at all.
- `scripts/charge-mode.sh park|normal|status|toggle` wraps all of this.

### Type-C power-role swap (a lever, with caveats)

`echo source > /sys/class/typec/port0/power_role` stops the laptop drawing from the
monitor; DP survives it at 4K60. Caveats, all observed:
- It **propagated to the other ports** after ~10 min on 2026-10-22, silently killing
  charging from a separate charger.
- A **replug resets it to `sink`** by itself.
- With no live contract the write fails `EIO` and logs `unknown error 0`.

---

## 7. Deliberately out of scope

- **The kanshi workspace reshuffle.** `~/.config/kanshi/config` lists `mirrored`
  before `docked`; both match the connected set {DP-1, eDP-1}, so `mirrored` always
  wins, and its `exec` moves all ten workspaces to `eDP-1` and steals focus on
  *every* re-apply. That is why a 1-second blip feels catastrophic. It is a config
  problem, not a hardware symptom. **Do not spend time here and do not change it
  without asking the user** — they use both screens simultaneously, so promoting
  `docked` (which does `output eDP-1 disable`) would be wrong.
- **An automatic udev+systemd charge policy.** Was built, then deleted as
  over-built. Don't rebuild it.

---

## 8. Open questions for someone with source access

1. **Why does the DRM connector drop with no log line?** Trace the DP alt-mode HPD
   path end to end: `drivers/usb/typec/altmodes/displayport.c` →
   `drivers/usb/typec/ucsi/displayport.c` → `typec_altmode` notifier → the `xe`
   display code. Which layer decides the sink is gone, and why is it silent?
2. **Is this DP link-training failure, an HPD glitch, or a PD hard reset?** Never
   established. The 2026-10-13 ucsi trace caught firmware `connected=0` → connected
   as source → sink with the old RDO restored, but **no command events appeared**,
   and it does not establish physical CC/VBUS behaviour or who initiated the reset.
3. **Does `xe` differ from `i915` here?** The Ubuntu kernels carry an i915 DP-alt
   false-disconnect fix (LP: #2143879). This machine runs `xe` on Panther Lake.
   Does the equivalent fix exist in `xe`? This is a concrete, checkable question.
4. **Why does the monitor's hub fail to re-enumerate on redock?** It last appeared
   at 12:39 and did not return at either of the two later redocks. Possibly a
   second, independent defect; possibly the same one seen from the USB side.
5. **Why is the VDO `0xff01a043` near-identical across three different partner
   devices?** Suggests it originates from the laptop's PD controller, not the
   partner. Unexplained since 2026-09-30.
6. **Why does charge current raise the rate so sharply** if the fault is in the
   video link? Thermal? Rail noise coupling into the CC/AUX lines? This is the
   bridge between section 6 and section 4 and nobody has a mechanism for it.

### Diagnostics worth collecting (not yet done)

```sh
# DRM/xe display debug — the gap in the evidence
sudo sh -c 'echo "module xe +p" > /sys/kernel/debug/dynamic_debug/control'
# or boot with: drm.debug=0x1e log_buf_len=8M

# UCSI tracepoints (a capture already exists, see below)
sudo trace-cmd record -e 'ucsi:*' -o /var/tmp/usbc-$(date +%Y%m%d-%H%M%S).dat sleep 900

# the only count that means anything
journalctl -b | grep -c 'Destroying output DP-1'
```

An earlier trace is at **`/var/tmp/usbc-20261013-154555.dat`** (3.3 MB, root-owned),
readable with `trace-cmd report -i …`. Altmode fields show `[FAILED TO PARSE]` —
that is a report-decoder issue, the raw fields are present.

---

## 9. Corroborating evidence from outside this machine

- **User-reported: Windows on this same Dell shows the same disconnects.** That
  makes a Linux-driver-only cause unlikely, and points at firmware/hardware.
- **User-reported: the vendor-supplied cable works with a Mac.** So not simply a
  bad cable.
- **User-reported: charging from a *separate* port while the monitor is connected
  works.**
- **Plugable, on Dell XPS/Precision:** the USB-C instability "primarily affects
  transmission of USB data packets" and DP Alt Mode video "seems much less likely
  to be impacted". A known family-level failure mode. Note this is the *opposite*
  shape to Pattern B, where video drops and USB is uninvolved.

---

## 10. Untried levers

| Lever | Status |
|---|---|
| **USB-C → DisplayPort cable** (DP 1.4 / HBR3), charging separately | **The leading candidate.** Removes PD and USB entirely, leaving only the video link — which is where the fault now appears to live. Costs single-cable docking. 4K60 8-bit needs ~12.5 Gbit/s; 4 lanes of HBR2 give ~17.3, so DP 1.2 suffices, but buy 1.4 for headroom. |
| BIOS `VideoPowerOnlyPorts` | Staged and **reverted untested** on 2026-10-23. Dell documents it in one ambiguous sentence ("Enable or disable the Type-C port functionality to video or only power") and the Latitude 3420 manual says it applies only to systems **with a discrete video card** — this machine has none, so it is probably inert. It is also **global across all Type-C ports**, not per-port. |
| Newer/mainline kernel | Mainline can be *worse* (no SAUCE patches). Any installed test kernel becomes the GRUB default and the menu is hidden — **Esc at boot** is the way back. |
| `TypeCDockOverride`, `ThunderboltPorts`, `DisUsb4Pcie`, `UsbPortsExternal` | All present under `dell-wmi-sysman`, all untouched, semantics unverified. |

**Confirmed 2026-10-23: `dell-wmi-sysman` writes do stick** — writing
`VideoPowerOnlyPorts` flipped `attributes/pending_reboot` to `1`. That had been an
open question since 2026-10-13.

---

## 11. Working constraints

- **`sudo` cannot be run from the agent session at all** — not non-interactively,
  not via the `!` prefix. Hand the user exact commands to run themselves.
- Don't restart the user's services or Wayland session; give the command.
- Commit directly to `main`; **never** add Claude attribution to commits.
- `agents.md` (symlinked as `CLAUDE.md`) usually has unrelated pending edits —
  stage only your own section.
- This machine's live `/sys` charge settings are **not tracked by the repo**.
  Originals and revert commands are in the long-form doc's *Live changes* section.
