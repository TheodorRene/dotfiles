# Environment

## Hardware
- **Machine**: Dell XPS 14, 16 cores, 30 GB RAM
- **Panel**: 1920x1200 (16:10), 120 Hz; only mode the eDP advertises
- **Swap**: 16 GB zram (zstd, primary) + 8 GB disk swapfile (overflow)

## OS & Desktop
- **OS**: Ubuntu 26.04 LTS
- **Display server**: Wayland
- **Compositor**: Sway (i3-compatible tiling WM)
- **Status bar**: Waybar
- **App launcher**: Wofi
- **Display config**: Kanshi (dynamic output management)
- **Desktop portal**: xdg-desktop-portal (Wayland variant)
- **Notifications**: mako

## Keyboard
- **ZSA Voyager**; keymap is built in ZSA's online configurator (Oryx) — that's
  the source of truth, and the firmware is flashed from Oryx/Keymapp.
- The firmware source is **not** kept in this repo; Oryx's "Download source" zip
  is the readable form when a keymap question comes up.
- Open/optional: æøå on the Voyager via `us(altgr-intl)` + three Oryx remaps.
  **Nothing applied**; the Voyager's Nordic keys are still dead.
  **Revised 2026-10-16: the laptop keyboard stays `us,no`**, because the user
  types Norwegian on it. So the plan is per-device: `type:keyboard` gets
  `altgr-intl`, and an `input "1:1:AT_Translated_Set_2_keyboard"` block keeps
  today's settings (diff passes `sway --validate`).
- **Gotcha: today the layout switch is shared between keyboards.** sway's
  default `keyboard_grouping smart` syncs the layout across keyboards with the
  same keymap, so switching the laptop to `no` also switches the Voyager.
  Different keymaps mean separate state.
- **Gotcha: `input` precedence (identifier > `type:` > `*`) applies only in the
  config file.** A typed `swaymsg input type:keyboard …` overrides per-device
  settings, so in a live trial run the laptop's commands last.
- **Checked 2026-10-16: `altgr-intl` doesn't change Alt in nvim or the
  terminal.** Diffing the compiled keymaps: Left Alt is `Alt_L` on Mod1 in both.
  Right Alt is Compose today (not on Mod1), so every Alt that works now, the
  right home-row one included, is already Left Alt. Normal and Shift typing are
  identical on every key except the modifiers, Menu and the ISO `<>` key.
- **Gotcha:** waybar's `custom/language` reads the *first* keyboard in
  `get_inputs`, which is a Voyager device. After the split it has to select the
  laptop's identifier.
- Write-up: `docs/nordic-letters-on-us-layout.md`: the per-device sway diff,
  commands for a live trial, the keymap diff and how to reproduce it, the Oryx
  remap table, order of operations, how to reverse it, open questions, and a
  layer-by-layer cheat sheet of the layout as of 2026-08-03.

## Terminal & Shell
- **Terminal**: Alacritty (what the user actually runs); kitty is also configured (its config was ported from Alacritty) but is not the daily driver
- **Shell**: zsh (self-contained config, no framework; `.zshrc` sources
  `~/dotfiles/zsh/*.zsh` and builds its own prompt via a `precmd` hook)

## Editor
- **Primary**: Neovim (`$EDITOR` and `$VISUAL` both set to `nvim`)
- Man pages open in Neovim (`MANPAGER=nvim +Man!`)
- Config is `nvim_v2/` (symlinked to `~/.config/nvim`). It has its **own
  `agents.md`** — read it before touching the config; it's 0.12-specific
  (`vim.pack`, native LSP, no lazy.nvim) and most external advice doesn't apply.
  New-machine prerequisites are in `nvim_v2/SETUP.md`.

## Runtimes & Package Managers
- **System packages**: apt
- **Node.js**: managed via nvm (sourced eagerly in `.zshrc` from `~/.nvm`)
- **npm globals**: installed to `~/.npm-packages`

## Wayland-specific env
- `MOZ_ENABLE_WAYLAND=1` — Firefox runs native Wayland
- `XDG_CURRENT_DESKTOP=sway`
- `ELECTRON_OZONE_PLATFORM_HINT=wayland` — Electron apps use Wayland
- `GTK_USE_PORTAL=0`

# Repository

Dotfiles are deployed as symlinks by `symlinkifier.pl`:
- Whole `~/.config/<name>` dirs (sway, waybar, kitty, alacritty, kanshi, mako,
  swaylock, xdg-desktop-portal, opencode…) — listed in the `.config` loop.
- Individual files (e.g. `~/.claude/settings.json`, user systemd units like
  `~/.config/systemd/user/*.slice`) — one `symlink_path(...)` line each.
- **System** configs live under `etc/` and are symlinked into `/etc/` by
  installer scripts in `scripts/` (e.g. `install-oomd-tuning.sh`), NOT by
  `symlinkifier.pl`.
- Helper scripts live in `scripts/`; longer-form notes in `docs/`.

To add a config: put it in the repo, add the symlink line to `symlinkifier.pl`
(or the relevant installer), then run it.

# Conventions

## Git
- **Do not create branches for this project — commit directly to `main`.**
- **Never add Claude attribution to commits** (no `Co-Authored-By: Claude`
  trailer, no "Generated with Claude Code" lines).

## Applying changes
- **`sudo` cannot be run from here at all.** It won't run non-interactively,
  and the `!` prompt prefix does **not** support an interactive sudo password
  prompt either. For anything needing root (installer scripts, `apt install`),
  hand the user the exact command and let them run it in their own terminal.
- Don't recreate/restart the user's running services (Docker containers, dev
  servers, the Wayland session) yourself — give the command and let them run it
  at a safe point.

## Documenting things
"Write it up in docs" / "document it" means **two** edits, always both:
1. A write-up in `docs/<kebab-case-topic>.md`.
2. An index entry in `agents.md` (`CLAUDE.md` is a symlink to it), as bullets
   under the relevant `## System notes` subsection — new subsection if none fits.

Do **not** reach for the `impero-ai-skills` doc skills here; those are for work
repos only. This repo's docs are plain markdown files, nothing else involved.

### What a write-up looks like
- `# Title` naming the **symptom or the change in plain words**, not the tool
  (`The USB webcam is unusable for the first minute after plug-in`, not
  `uvcdynctrl`). These get found by symptom, months later.
- A **`**Status:**` line right under it**: `APPLIED <absolute date>`, or
  `Nothing applied` for a plan. Always absolute dates — never "last week".
- Then: symptom → cause (with the actual log lines / config text as evidence) →
  the fix as **exact copy-pasteable commands** → **verified end state** (the real
  command output proving it took) → how to reverse it.
- **Separate what's verified from what's theorised**, explicitly. Mark leftover
  puzzles as unexplained rather than papering over them, and keep a dead-ends
  list so the same wrong theory isn't rebuilt later (see
  `docs/luks-boot-emergency-shell.md`).
- Say when something is **not tracked by this repo** (in-place `/etc` edits,
  `/dev/null` masks) and what to re-run after a reinstall.

### What the `agents.md` entry looks like
- Bullets, each leading with the **load-bearing claim in bold** — the thing that
  would otherwise be re-derived or got wrong once.
- Prefer gotchas and negative results over description; `**Gotcha:**` and
  `**Dead end, don't re-theorise:**` are the useful ones.
- Mark state as `**Applied <date>:**` or `Open/optional:` … `**Nothing applied.**`
- Close with a `Write-up:` line pointing at `docs/<file>.md` and saying what's in it.

### Committing
`agents.md` usually has unrelated pending edits in the working tree. **Stage
only your own section** (`git add -p`), never the whole file.

# System notes

## Memory / OOM
- 30 GB RAM gets overcommitted by the dev workload (rust-analyzer, frontend Node
  tooling, Firefox, .NET) and `systemd-oomd` has killed the whole graphical
  session — everything shares one session cgroup, so the only thing oomd can
  evict is the entire session.
- Mitigations in place: 16 GB zram + oomd tuned to kill on sustained **memory
  pressure** (60% / 20s), not swap fullness (`ManagedOOMSwap=auto`). Configs in
  `etc/systemd/{zram-generator.conf,oomd.conf.d,system/user.slice.d}`, applied
  by `scripts/install-oomd-tuning.sh`.
- **`scripts/mem-report.sh`** — human-readable memory assessment (RAM, swap/zram
  with compression ratio, PSI pressure, oomd kills, top workloads by RAM).
- **Gotcha:** in process lists, `comm = MainThread` is **Node.js** (frontend
  LSPs — eslint/typescript — plus vite/webpack), **not .NET**. Don't attribute
  "MainThread" RSS to the .NET backend (a mistake made once). `mem-report.sh`
  classifies by full cmdline to avoid this.
- Firefox under Fission spawns one process per site, and **embedded iframes show
  up as standalone site processes** (e.g. a Figma embed inside a Shortcut ticket
  looks like a 640 MB `figma.com` process). Check the `about:memory` URLs, not
  the process name.
- Open/optional: `docs/rust-analyzer-memory-cap.md` — plan to cap rust-analyzer
  (a repeat OOM offender) in a memory-limited cgroup slice.
- **`kdump` reserves 512 MB for a dump it can never write.** `crashkernel=…:512M`
  is armed, but the capture initrd (built by *initramfs-tools*, not dracut) has no
  `cryptsetup`/`dm-crypt`, and `/var/crash` is inside LUKS — so it cannot mount its
  own dump target. Never captured anything. Cause: `cryptsetup-initramfs` isn't
  installed (nothing needs it, since the boot initrd is dracut). Write-up:
  `docs/kdump-cannot-capture-on-luks.md`. **Nothing applied** — note that
  `systemctl disable` alone does *not* release the reservation.

## Boot / disk
- Root is **LUKS-encrypted**: `nvme0n1p8` (LUKS) → `dm_crypt-0` → `ubuntu-vg/ubuntu-lv`
  → `/`. So an initramfs complaining `/dev/ubuntu-vg/ubuntu-lv does not exist` is
  **not an LVM fault** — it means the LUKS unlock never completed.
- The boot initramfs is **dracut** (systemd-based), *not* initramfs-tools, so most
  Ubuntu advice and its knobs don't apply. `rdsosreport.txt` is dracut's emergency
  dump. **Caveat:** `initramfs-tools-bin` and `initramfs-tools-core` *are* installed
  — `kdump-tools` uses them to build its crash-capture initrd from its own config
  tree at `/var/lib/kdump/initramfs-tools/`. Nothing on the **boot** path does.
- Happened once (2026-08-05, fixed by a reboot). Hardware ruled out; **cause not
  established** — several theories were built and killed by later evidence, so read
  the write-up before theorising. What *is* solid: the ~90s hang matches
  `DefaultDeviceTimeoutUSec`, so the **LV device job** timed out, not the passphrase
  step (`systemd-cryptsetup` has `TimeoutSec=infinity`).
- **New evidence 2026-09-04:** prompt→passphrase gaps of **27.7s / 41s / 90.4s /
  114.7s** occur on boots that then succeed, while unlock→LV was 0.3s on all 21
  boots measured. So the LVM branch is nearly dead and the incident looks like *the
  ordinary long gap, one second past the 90s device timeout*. Missing discriminator:
  whether those gaps are the human typing late or keystrokes not reaching plymouth
  — not in the logs, and not recalled. **Next time the spinner drags: type one
  character and see if a dot appears.** That single observation settles it.
- If it recurs, **run `ls /dev/mapper/` first** — `dm_crypt-0` present means an LVM
  activation failure, absent means the unlock never happened. That datum is
  unrecoverable afterwards (`/run` is tmpfs, and a failed boot leaves no journal).
- Write-up: `docs/luks-boot-emergency-shell.md` — symptom record, verified mechanics
  (incl. the trap that `rd.lvm.lv` **is** set via `hostonly_cmdline` inside the
  image, not `/proc/cmdline`), a dead-ends table, in-place recovery without
  rebooting, and candidate grub changes. **Nothing applied.**
- **There is no "the boot time"** — measured across 21 boots (2026-09-04) the total
  ranges **19s to 2min 29s**. Never reason about boot speed from one
  `systemd-analyze` run; the earlier "~35s, ~13s of it typing" figure was one
  unrepresentative sample. What does hold:
  - **The decryption is never the slow part**: argon2 was **2.0s on all 21 boots**,
    and unlock→LV another 0.3s. If a boot feels slow, don't look at the crypto.
  - **`systemd-analyze` counts the human typing the passphrase**, and that gap ran
    **3.4s to 114.7s**. It's the largest and least predictable term.
  - **Plymouth holds the screen ~10.5s *after* the desktop is painted** on 17 of 21
    boots (`plymouth-quit-wait.service`, `TimeoutSec=0`, so not a systemd timeout);
    that alone is the whole 13.5-14.9s vs 3.6-4.4s split in `userspace`. This is
    what "I typed my password and got a spinner for ages" actually is.
  - GRUB (`loader`) swings **2.1s → 14.1s** for the same 58 MiB read, so the old
    "~8.5 MiB/s constant" explanation is wrong; firmware usually 5.4s but has hit
    28.7s. Both unexplained. FPDT is the source of those two numbers (no `Loader*`
    EFI vars exist here).
  - `systemd-analyze blame` misleads: its top ~30 `*.device` entries just inherit
    the initrd duration — filter with `grep -vE '\.device$'`.
  - Open/optional: `docs/boot-time-budget.md` — the 21-boot table, the four
    markers that decompose any single boot, and ranked fixes (TPM2 auto-unlock;
    dropping `quiet splash`, which kills the plymouth stall *and* makes the next
    hang legible). **Nothing applied.**
- `smartmontools` **is** installed, but `smartctl` (and `tune2fs`) need root:
  `sudo smartctl -a /dev/nvme0n1`.

## External displays (USB-C) / kernel choice
- Monitor is an **LG 27U730A**. **Two problems, one per cable** (2026-09-30):
  laptop USB-C → the monitor's USB-C input **drops and re-attaches every ~30s**;
  a no-name USB-C→HDMI adapter (`343c:0000`) is stable but **4K30 only**.
- **Dead end, don't re-theorise: the OEM kernel didn't fix the drops.**
  `linux-oem-26.04` (7.0.0-1014, **applied 2026-09-28**, still the default boot)
  has the corrected UCSI duplicate-altmode patches (LP: #2162695). The warning's
  wording changed, so the patch is live, but the drops continued unchanged. The
  `duplicate partner altmode SVID 0xff01` warning is **cosmetic**: DP comes up
  even when no altmode registers.
- **Current theory, not verified: the charging negotiation.** The link that drops
  is the one where the monitor *charges the laptop*; the stable adapter link has
  the laptop as the power source. The drops re-register the partner (a CC/PD-level
  detach, not a DP-link loss). **Gotcha:** `UCSI_GET_PDOS failed (-70)` shows up
  on *every* attach, the stable adapter included, so it isn't the smoking gun. Next tests: another
  e-marked 5A cable, Dell charger plugged in first, other TB port. **Likely way
  around it:** a USB-C → DisplayPort cable (no charging negotiation, 4 lanes).
- **Latest, 2026-10-12, waiting on a report: the direct USB-C cable is at 4K60
  and hasn't dropped yet** (kernel `7.0.0-1015-oem`), but that was only ~6 min
  observed and **with a full battery**, so the charging theory isn't tested by it.
  **Known-good 4K60 paths:** the monitor's USB-C (when it holds) and the ThinkPad
  TB3 Dock (40AN, needs its own brick). The VIA hub and the HDMI adapter cap at
  4K30. The doc's *History* table logs every connection; **add a row per test.**
- **4K30 over HDMI is the adapter, not the monitor.** The adapter gets 4 DP lanes
  (pin C), and "HDMI ULTRA HD Deep Colour" is on, but the EDID it passes on lists
  **VIC 95 (4K30) three times** and no 4K60. That looks like the adapter
  rewriting it to fit an HDMI 1.4-class chip. Don't chase kanshi modes or monitor
  settings for it.
- **Gotcha: there is no HDMI connector on this laptop.** DRM exposes only
  `DP-1..3` + `eDP-1`, so "HDMI" always means a USB-C adapter or hub. **USB-C hubs
  with USB 3 ports use pin D = 2 DP lanes = 4K30 max** (the 2026-09-11 hub:
  `max_lane_count: 2`).
- **`ubuntu-drivers list-oem` printing nothing does not mean there's no OEM
  kernel**; it only means Ubuntu doesn't recommend one. **Mainline can be *worse*
  here**: no SAUCE patches, incl. the i915 DP-alt false-disconnect fix
  (LP: #2143879) the Ubuntu kernels carry. Any installed test kernel **becomes the
  GRUB default**, and the menu is hidden, so **Esc at boot** is the way back.
- **Gotcha:** `apt changelog linux-image-*-oem` shows the *signed wrapper's*
  changelog (packaging resyncs only). Read the source changelog on
  changelogs.ubuntu.com.
- **Live `/sys` changes are currently applied (2026-10-13) and are NOT tracked by
  this repo** — `charge_types` `Fast`→`Custom`, `charge_control_end_threshold`
  `90`→`55`, and `port0` (plus seemingly `port1`/`port2`) `power_role`
  `sink`→`source`. Originals and exact revert commands are in the write-up's
  *Live changes made 2026-10-13* section. **Revert explicitly; a reboot probably
  won't**, since the charge settings are backed by a BIOS policy.
- **Gotcha, cost three bad tests: the charge *thresholds* work, the charge *rate*
  selector does not.** `charge_control_start/end_threshold` apply only from a
  fresh cycle — written mid-charge they do nothing (which is where the original
  "sysfs accepts it, the EC ignores it" came from). On a clean start the `50/55`
  window is exact: 31%→55% at ~31 W, then `pending-charge` at 0.011 W the instant
  it hit 55. **`charge_types` is cosmetic as a rate** — `[Trickle]` reads back
  fine and charges at **32.6-32.8 W** anyway, measured both mid-charge and from
  cold. **There is no slow-charge mode reachable from sysfs on this machine.**
  Always check `BAT0/current_now` rather than the knob's own readback.
- **`charge_types` also picks which policy is live**, so `Trickle` drops you out
  of `Custom` and the `50/55` window stops gating — it then charges past 55 toward
  full. `echo Custom | sudo tee …/charge_types` restores the window.
- **`Not charging` with `AC online = 1` is the healthy in-band state** — the
  battery is between the start and stop thresholds and the EC is holding off. It
  is *not* the same as `Discharging` (no AC at all), which is what the Type-C
  power-role swap produces. **DP survived the swap** — 4K60 held with the laptop
  as power source.
- **The charge window cannot go below 50/55**: BIOS caps `CustomChargeStart` at
  `50..95` and `CustomChargeStop` at `55..100`. "Set the window under the current
  level to stop charging" only works above 55%.
- **The real control surface is `dell-wmi-sysman`, not `power_supply`** —
  `/sys/class/firmware-attributes/dell-wmi-sysman/attributes/` has
  `PrimaryBattChargeCfg`, `CustomChargeStart/Stop`, `UsbPortsExternal`,
  `ThunderboltPorts`. **Gotcha:** `current_value` is root-read-only and a
  non-root `cat` returns **empty, not an error** — that is not "unset". No BIOS
  admin password is set. Untested whether writes stick.
- **No usable GUI.** BIOS setup (Esc then F2 at boot) is authoritative;
  `gnome-control-center power` is installed but drives the ignored
  `charge_control_end_threshold`; TLP would persist the same ignored paths and
  **TLPUI isn't in the Ubuntu archive**; `cctk` isn't packaged.
- **Timing trap when testing:** the fault is **bursty, not periodic** (5 re-attaches
  in 5 min as two clusters with a 2m43s gap), and on 2026-10-13 it went quiet at
  09:09 **while still fast-charging**, ~5 min *before* the power-role swap. Don't
  credit a change with a lull; ten quiet minutes is the bar.
- **CAUSE FOUND 2026-10-13: it is the battery charge current, not the PD
  negotiation.** Controlled A/B, one session, one cable, one port, one live PD
  contract, only the charge current changed: **parked** (`pending-charge`, 0.011 W)
  → 65 min, **0 re-attaches**; **charging** (2.698 A × 12.07 V = **32.6 W**) →
  11 min, **3 re-attaches** (15:24:10, +4m21, +1m28). ~18 events expected in the
  parked window at the charging rate; Poisson p ≈ 1e-6.
- **Dead end, don't re-theorise: the PD negotiation is not the cause.** Through the
  whole 65-min quiet window the contract was *live and delivering* — 20 V / 4.5 A,
  `port0 [sink]`, and the battery discharge went 3.4-4.6 W before the replug to
  0.011 W after, i.e. the cable carried the entire system load. A negotiated,
  active, power-delivering contract is stable. `GET_PDOS failed (-70)` stays
  cosmetic.
- **`pending-charge` at ~0 W is a stable equilibrium, not a decaying workaround.**
  Plugged in and in-band, the battery neither charges nor drains (capacity unmoved
  for 66 min), so it never falls below the start threshold and never triggers a
  charge. **This is the free fix**: `echo Custom | sudo tee …/charge_types` with a
  `50/55` window. Costs ~55-62% at undock, plus ~6 min of flicker per 5% whenever
  you do top up.
- **User-confirmed 2026-10-13: separate-port charging works with the monitor
  connected; Windows on this Dell has the same disconnects; the vendor-supplied
  cable works with a Mac.** These are independent user reports, not inferred
  from the 13:05–13:33 charge with the monitor unplugged. Single-cable operation
  remains the goal.
- **`scripts/charge-mode.sh`** — toggles between `park` (Custom 50/55, no charge
  current, use when the monitor is powering the laptop) and `normal` (Fast 50/90,
  the factory setting). Also takes `park`/`normal`/`status`. Prompts for sudo
  itself; writes `/sys` directly so **nothing is installed and nothing persists a
  reboot**. An automatic udev+systemd version was built and **deliberately
  dropped as over-built**; don't rebuild it.
- **Trap when reading the afternoon logs: the 13:05–13:33 charge proves nothing
  about the display** — it was a charger on a *different port* with the monitor
  unplugged (display-change hook ran 13:00:01, next at 14:13:13). Check the hook
  timestamps (`journalctl -b | grep '+ is_active'`) before treating any quiet
  window as evidence; the monitor may simply not have been attached.
- **Likely reason the `power_supply` knobs lose: `PrimaryBattChargeCfg` defaults to
  `Adaptive`**, and the 2024 `dell-laptop` patch says Linux's thresholds drive the
  **`Custom`** BIOS mode. Theorised, fits the measurements. **`PrimAcUse`
  ("Primarily AC Use") is the simpler cap** — no thresholds, sidesteps the 50/55 floor.
- **Gotcha:** `pending_reboot` (world-readable, currently `0`) tells you if a BIOS
  write needs a reboot; `dell_value_modifier` can force a value from another setting
  (empty on everything here). No BIOS admin password is set, so no `current_password`
  dance.
- **`VideoPowerOnlyPorts`** ("Video/Power only on Type-C Ports", default `Disabled`)
  is the tempting experiment — the monitor's USB hub is unused on this link anyway.
  **Semantics unconfirmed by Dell docs**; whether it touches PD is speculation.
- **Supporting finding (Plugable):** on Dell XPS/Precision the USB-C instability
  "primarily affects transmission of USB data packets" and DP Alt Mode video "seems
  much less likely to be impacted" — **exactly the shape here** (DP holds 4K60 while
  PD churns). A known family-level failure mode, not this monitor.
- **Latest evidence, 2026-10-13: charging exposes the fault; the electrical root
  cause is NOT established.** This supersedes the earlier “cause found / PD
  negotiation ruled out” wording above. The targeted trace caught two cycles:
  firmware `connected=0` → connected as source → sink, with the old RDO restored.
  This does not establish physical CC/VBUS behaviour or who initiated a reset.
  No command events appeared in the `ucsi:*` capture; investigate that next.
- **Applied 2026-10-13 15:52:51: Custom restored, battery parked.** Charging at
  32.9 W after 15:51:41 produced interruptions at 15:52:14–15 and 15:52:43–44;
  BAT0 verified at 62%, `Not charging`, 1000 µA at 15:53:30. Earlier last drop
  15:31:27 was **before** the Custom write at 15:31:38, not caused by that write.
- **Gotcha: `Trickle` maps to Dell Primarily AC Use, not a low-current request.**
  Upstream `dell-laptop.c` uses `BAT_PRI_AC_MODE_TOKEN`; earlier “cosmetic/no-op”
  and “BIOS PrimAcUse is a new fix” interpretations are superseded. Exact OEM
  source not verified. Upstream UCSI `current_now`/`voltage_now` are cached
  RDO/PDO-derived values, **not electrical measurements of the cable**.
- **Trace saved outside the repo:** `/var/tmp/usbc-20261013-154555.dat`, readable
  with `trace-cmd report -i …`. Altmode `[FAILED TO PARSE]` is a report-decoder
  issue; raw fields are present. The doc's *2026-10-13 targeted trace* section
  has the exact trace, replay/capture commands, limits and corrected conclusions.
- **Start here if you pick this up cold: `docs/usb-c-disconnect-handoff.md`** — the
  distilled state of play for a fresh investigator, and it **supersedes the
  "CAUSE FOUND" claim above**. Key reframing (2026-10-23): a merged timeline over
  one boot gives **23 display losses vs 24 PD re-attaches**, and they do *not*
  pair up — PD re-attaches occur with no display loss and vice versa. Where they
  do pair, **the display dies 2-3 s BEFORE the PD event**, so `duplicate partner
  altmode` is the echo, not the trigger. **Count `Destroying output DP-1`, not the
  PD line.** Charge current still raises the rate sharply (the 2026-10-13 A/B
  stands) but is **not necessary** — 2026-10-19 and all of 2026-10-23 dropped with
  the battery parked at 0.0 W.
- **Gotcha that produced a bogus theory once: classify every display loss by how
  long the output stayed gone.** 1-2 s is a fault; minutes means the user undocked
  for a meeting. On 2026-10-23, 3 of 23 losses were 23/40/36-minute unplugs, and
  counting them as faults generated a whole "two distinct failure patterns"
  hypothesis that evaporated once they were excluded.
- **Corrected 2026-10-23 counts: 20 real faults, 3 unplugs, and the accounting
  closes exactly** — 24 PD re-attaches = 20 faults + 4 plug events. Every real
  fault has **exactly one** PD re-attach 1-3 s *after* the display loss; every PD
  event without a display loss is a plug; every display loss without a PD event is
  an unplug. **One mechanism, not two.** The display recovers by itself in 1-2 s.
- **The monitor's USB hub is not involved in the faults.** `usb 3-2` last
  enumerated 12:39:09 and never returned across two later redocks, so all 18
  afternoon faults happened with **no hub attached**. Separate `3-2` (hub) from
  `3-1` (Voyager) when grepping — conflating them misleads.
- **The DRM connector drop logs nothing at all** (no `xe`/`drm` line at default
  verbosity) — instrumenting the DP/HPD path is the highest-value next step.
- **Confirmed 2026-10-23: `dell-wmi-sysman` writes do stick** (writing
  `VideoPowerOnlyPorts` flipped `pending_reboot` to `1`), closing an open question.
  **Gotcha: `pending_reboot` is at `attributes/pending_reboot`**, not the class root.
  `VideoPowerOnlyPorts` was **reverted untested** — Dell documents it in one
  ambiguous sentence, it is **global across all Type-C ports**, and the Latitude
  3420 manual says it applies only to systems **with a discrete GPU**, which this
  machine does not have.
- **Current setup since 2026-11-02: a USB-C → DisplayPort cable on port0, and
  the charger on a separate USB-C port** (port2 on 2026-11-05). **0 display
  losses in about 8.5 h docked**, including charging at 2.7 A, so the workaround
  holds. Single-cable docking is still broken and **not fixed**. **Gotcha:**
  `Page-flip failed on output DP-1` (EBUSY) still shows up a few times per boot.
  It is **not** a dropout (no `Destroying output`), and it's unknown whether it's
  visible.
- Write-up: `docs/usb-c-displays-disconnect-and-kernel-options.md`: traces, VDO
  pin decodes, the EDID decode, the charging theory and its tests, a dated
  *History* table of every connection tested, the 2026-10-13 live changes with
  their revert commands, how to try OEM/mainline kernels and revert, where
  changelogs live, and a dead-ends table.

## HDR
- **The LG monitor supports HDR10; the laptop panel can't.** The LG's EDID
  (`LG ULTRAFINE`, product 23740) has ST 2084 (PQ), BT.2020 and 10 bpc, but only
  400 nits and no sign of local dimming (DisplayHDR 400 class), so expect
  HDR10 compatibility rather than a dramatic picture. The Sharp `LQ140N1` panel's
  only colour space/EOTF is sRGB.
- **Everything below sway is ready (checked 2026-11-02):** `xe` exposes
  `HDR_OUTPUT_METADATA` and `Colorspace` (incl. `BT2020_RGB`) on the DP
  connector, and the USB-C→DP cable runs **HBR2 × 4 lanes** (DPCD `14 84`),
  17.28 Gbit/s against the 16.0 Gbit/s that 4K60 10-bit needs.
- **The blocker is sway 1.11**, which has no `hdr` output option. HDR10 arrived in
  **sway 1.12 + wlroots 0.20** and needs **`WLR_RENDERER=vulkan`**. Today
  sway runs GLES2; the Vulkan driver works.
- **Gotcha: 4K60 working doesn't prove 4 lanes.** 8-bit 4K60 fits on 2 lanes of
  HBR3; only 10-bit needs 4. The 2-lane hubs and the HDMI adapter can't carry it.
  Check with `sudo dd if=/dev/drm_dp_aux1 bs=1 skip=256 count=2 status=none | xxd`.
- **26.04 stays on 1.11; 26.10 ("stonking") has 1.12-1**, and its sway +
  `libwlroots-0.20` depend on nothing newer than 26.04 has, so a pinned
  two-package install works on paper. **Nothing applied** (user chose to wait).
- **No way to test HDR inside sway 1.11.** Use the installed GNOME session
  (Settings → Displays → HDR) or mpv on a text console.
- Write-up: `docs/hdr-on-external-monitor.md`: both EDID decodes, the drm_info
  and link evidence, the renderer check, the pinned-apt upgrade commands with
  dependency table and how to reverse it, and verified vs theorised.

## Printing / cellular (unused hardware daemons)
- **Applied 2026-09-03: printing and `ModemManager` are OFF.** `cups.service`,
  `cups.socket`, `cups.path`, `cups-browsed.service` and `ModemManager.service` are
  all disabled; the `cups` **snap is removed**. `lpstat -p` now says "Scheduler is
  not running". ~112 MB of RSS reclaimed.
- Two **complete CUPS stacks** had been running at once (deb `cups`+`cups-browsed`
  *and* `snap.cups.*`). The printers `lpstat` used to show were **not added by
  hand** — `cups-browsed` has `BrowseRemoteProtocols dnssd` and auto-creates a
  queue for any printer advertised on the current network. **If printing is ever
  re-enabled, expect those queues to reappear on their own** — that's by design,
  not a leftover.
- **Gotcha if re-enabling:** CUPS is **socket-activated**. `cups.socket` alone
  brings it back; conversely, disabling only `cups.service` would not have stopped
  it. The deb units still show in `list-unit-files` as `disabled` (package still
  installed) — that is the expected end state.
- `ModemManager` was managing **no WWAN hardware of any kind** (`mmcli -L` → none;
  nothing on PCI or USB; only wifi + a USB ethernet dongle). It probes serial/USB
  devices with AT commands at boot, which is also why it can interfere with
  USB-serial gear (Arduino/ESP32/debug UARTs).
- Write-up: `docs/disable-printing-and-modemmanager.md` — what each does, why it
  was pointless here, verified end state, and how to reverse it.

## Bluetooth / wifi radio
- BT and wifi are **one Intel CNVi part** — `hci0` on PCI `00:14.7`, `iwlwifi`
  `wlp0s20f3` on `00:14.3` — sharing the RF front-end and antennas. Audio stack is
  PipeWire + WirePlumber (`libspa-0.2-bluetooth`); **`pactl` is not installed**, use
  `wpctl status` and `pw-dump` (`pw-dump | grep api.bluez5` gives the live profile
  and codec).
- Headphones are Bose (`Thrash Cans`, vendor `0x009E`), A2DP on **AAC**. They're
  **multipoint** and page their last-connected device on power-on, so a nearby phone
  wins the race — that part is not fixable from the laptop.
- **Applied 2026-09-04:**
  - `FastConnectable = true` in `/etc/bluetooth/main.conf` (page-scan interval; the
    file was otherwise entirely default). **`bluetoothd` supports no `conf.d`
    drop-ins**, so this is an in-place edit of a package conffile, *not* symlinked
    from this repo — re-run the `sed` in the write-up after a reinstall.
  - **Wifi power save off**, via `etc/NetworkManager/conf.d/zz-wifi-powersave-off.conf`
    + `scripts/install-wifi-powersave-off.sh`. Ubuntu's `network-manager` ships
    `default-wifi-powersave-on.conf` (`wifi.powersave = 3`); NM reads `conf.d`
    **alphanumerically**, later wins, so the override needs a `zz-` prefix — `90-`
    would sort *before* `default-` and silently lose.
  - **PBAP (phonebook) server off** — the Bose pull this laptop's phonebook on
    every connect, which woke `evolution-data-server` for nothing. `obex.service`
    is a **user** unit, so no root needed: `systemd/user/obex.service.d/override.conf`
    (`ExecStart=` cleared, then `obexd --noplugin=pbap`), symlinked by
    `symlinkifier.pl`.
- **`br-connection-busy` is not a failure.** It's `org.bluez.Error.InProgress`
  from `connect_profiles()` (`src/device.c`) when `dev->pending || dev->connect ||
  dev->browse` — a connect attempt is *already in flight*, so BlueZ refuses a
  second. blueman renders it as "Failed". **Clicking again does nothing**;
  blueman's AutoConnect plugin already retries every 60s (with the
  `GENERIC_CONNECT` all-profiles UUID), as does bluetoothd's `[Policy]` plugin.
- **Gotcha:** `obexd` defers plugin loading **~30s** after start. Inside that
  window the adapter advertises only its 11 non-obexd profiles, so a UUID count
  taken right after `systemctl --user restart obex.service` looks like everything
  broke. 18 UUIDs = PBAP off and correct; 11 = you checked too early.
- **Dead end, don't re-theorise:** 2.4 GHz co-channel interference from wifi is not
  the cause — wifi associates on **6 GHz** (ch 53, 160 MHz wide).
- Write-up: `docs/bluetooth-reliability-vs-phone.md` — ranked causes, the
  `br-connection-busy` decode, what was applied, inspection commands.
  Open/optional there: narrowing blueman's autoconnect to A2DP (unverified — would
  make the headset mic connect on demand), forcing SBC-XQ over AAC, and disabling
  `autoswitch-to-headset-profile`.
- **A Bluetooth mouse can show `Connected: yes` but never reach sway if it isn't
  *paired*.** Seen 2026-10-30 with the MX Master 4 (`MX Master 4 B`): `Paired: no`,
  `Trusted: yes`, and bluetoothd logged `hog-lib.c … failed: Request attribute has
  encountered an unlikely error` on every connect, with no kernel input device.
  **Clicking Connect again doesn't help.** Put the mouse in pairing mode (hold
  Easy-Switch ~3 s), then **Pair**. **Applied 2026-10-30**: bonded, sway sees
  `1133:45128:MX_Master_4_B_Mouse`.
- **Gotcha: `Trusted` isn't `Paired`.** Trusted only allows automatic connects.
  Check `Paired`/`Bonded` first. The pairing also belongs to one Easy-Switch
  channel and replaces that channel's previous host.
- **Verified 2026-11-02: it reconnects by itself after a reboot.** Not checked
  yet: after suspend, and the extra buttons/hi-res scroll. The kernel uses
  `hid-generic`, not `hid-logitech-hidpp`.
- Write-up: `docs/bluetooth-mouse-connected-but-pointer-dead.md`: the log
  lines, pair commands, verified end state, what to expect after a reboot, the
  "if it doesn't come back" check, and dead ends.

## Audio / suspend-resume
- **"Videos won't play in Firefox" after a wake from sleep means the speaker output
  is frozen, not that Firefox is broken.** Firefox times video off the audio
  output, so a stalled sink means video never starts, and restarting Firefox
  changes nothing. Seen 2026-10-06 after the **2% battery hybrid-sleep** (UPower's
  stock `CriticalPowerAction=HybridSleep`).
- **Fix: `systemctl --user restart pipewire pipewire-pulse wireplumber`**, then
  reload the tab. Worked first time. If it's still frozen after that, reboot.
- **How to recognise it:** with something *playing*, `hw_ptr` in
  `/proc/asound/card0/pcm*p/sub0/status` sits at `RUNNING` but doesn't change
  between two reads; `pw-top` shows a sink in state **`R` with QUANT 0 / RATE 0**.
- **Gotcha:** `wpctl status` looks perfectly healthy while this is happening
  (Firefox linked to `Speaker`, `[active]`). And with nothing playing, every PCM
  is just `closed` and the sink is `S` 0/0, which is normal, not this problem.
- **No kernel error is logged** for the sound card when it happens; it fails
  silently. Not established: SOF DSP vs PipeWire at fault, whether a plain
  lid-close suspend triggers it too, and whether the 2026-09-30 hybrid-sleeps
  (rebooted 17s later) were the same thing. **Nothing applied**; a resume hook is
  sketched in the write-up, only worth it if this recurs.
- Write-up: `docs/videos-wont-play-after-low-battery-sleep.md`: the frozen
  `hw_ptr` evidence and its resume timestamp, the 10-second check, verified vs not
  established, and a dead-ends table (Firefox, the same-day apt upgrade, routing,
  Bluetooth).

## Headphone EQ (3.5mm jack)
- **Applied 2026-10-15, repo-only: `scripts/eq.sh on|use|ab|pick|list|check|reload|off`**
  for A/B-testing EQ presets on the jack (HD6XX). Bare `eq.sh` (= `show
  [preset]`) draws the active preset's curve and bands. Presets are
  `audio/eq-presets/*.txt` in AutoEQ `ParametricEQ.txt` format, up to 7 at once,
  switched live with no gap. **`scripts/eq.sh off` restores everything.**
- **Nothing persists, by design**: it runs as a *transient* user unit `jack-eq`
  with its config in `$XDG_RUNTIME_DIR/jack-eq/`. **Never move it into
  `~/.config/pipewire/filter-chain.conf.d/`.** Ubuntu's `filter-chain.service`
  loads that directory at every boot, and that is how the 2026-10-14 attempt broke
  the user's audio (that, plus EasyEffects stacked on top).
- **Verified 2026-10-15:**
  - **The EQ is really applied**: a tone test through the jack's feed matched
    the preset's biquads within 0.03 dB, on both channels.
  - **A killed EQ falls back to the jack by itself**: WirePlumber ranks its
    *history* of defaults.
  - **After `off` nothing is left** except two harmless WirePlumber state lines.
- **Gotcha: `cs42l45 Headphone` *is* the PipeWire sink volume** (UCM
  `PlaybackMixerElem`, `softVolumes` 1.0), not a second gain stage to max out. So
  `scripts/volume.sh` moves the jack's node while the EQ is the default, and the
  EQ sink stays at 100%. **waybar's audio module shows `🔊 100%` while the EQ is
  on**, because it reads the EQ sink. The real level is in the volume-key popup.
- **waybar `custom/eq` shows 🎚️ before the audio module while the EQ is on**
  (dimmed on `flat`). It's fed by `eq.sh waybar` (no `pw-dump`, ~15 ms, 5 s
  poll), and `eq.sh` sends `RTMIN+10` on every change. RTMIN+9 is already taken
  by `image#viz`.
- **Gotcha: PipeWire's `param_eq` reads line 1 as the preamp, whatever it says**,
  and only understands `PK`/`LSC`/`HSC`. `eq.sh` normalises a copy and refuses
  other band types rather than dropping them.
- **Every option, `flat` included, is level-matched** to the most-attenuated
  preset, so the EQ is about 6 dB quieter than `off`. That's expected, not a fault.
- **Still left over from 2026-10-14:** the EasyEffects Flatpak (`--user`, not
  running) and 4 `easyeffects` lines in WirePlumber's `stream-properties`. Don't
  run EasyEffects alongside this.
- Write-up: `docs/headphone-eq-presets.md`: usage, how it works, everything it
  touches, restore steps (incl. by hand if the script is broken), the
  measurement table, what's not verified (reboot with EQ on, unplug, `pick`),
  and the 2026-10-14 dead ends.

## Webcam / USB video
- Built-in camera is the Intel **`ipu7`** block and claims **`/dev/video0`-`video31`**
  on its own. A USB webcam therefore lands somewhere above that (the Anker
  PowerConf C200 is `/dev/video33` capture + `/dev/video34` metadata). **Those
  numbers are not stable** — match on `ID_V4L_PRODUCT`, never a hardcoded index.
- **Applied 2026-09-08: `80-uvcdynctrl.rules` is masked.** Every UVC add event was
  running `/lib/udev/uvcdynctrl`, which spins for **over a minute** (udev logs
  "Spawned process ... is taking longer than 59s"). `RUN+=` is synchronous, so the
  node stayed at devtmpfs defaults `root:root 0600` — no `GROUP="video"`, no
  `uaccess` ACL — and **no app could open the camera until it finished**. It then
  self-heals, which is what makes it confusing.
- **`root:root 0600` on a `/dev/video*` node means udev never finished the event**,
  not that a rule set it that way. Check `stat`/`getfacl` against `/dev/video0`
  (correct: `root:video 0660` + a `uaccess` ACL) before suspecting the app or cable.
- **Replugging makes it worse** — the new node reuses the identical syspath, so its
  event queues behind the stuck one rather than starting fresh.
- `uvcdynctrl` ships extension-unit data for two vendors only (`046d`, `a0c8`), so
  it can never do anything for this hardware. Don't `apt purge` it — it's a
  dependency of `guvcview`; masking the rule is the fix.
- The mask is an in-place `/etc/udev/rules.d/` symlink to `/dev/null`, **not
  symlinked from this repo** (there's no file to track) — re-run it after a
  reinstall. Verify with `udevadm test`, not by eyeballing the directory.
- The C200 also registers a **mic** and steals the default PipeWire source from
  `sof-soundwire Microphones` when plugged in.
- Write-up: `docs/uvcdynctrl-udev-stall.md` — symptom, the timeline, the two
  commands, how to reverse it, and the one unexplained detail.

## Remote access
- No SSH server installed (`openssh-server` absent, so no `/etc/ssh/sshd_config`),
  no Tailscale. `mosh` **is** installed (the package is client + server); `tmux`
  and `screen` are in `/usr/bin`, but `zellij` only exists inside the impero nix
  shell.
- Open/optional: `docs/claude-code-from-phone.md` — plan to drive Claude Code from
  a phone over SSH + Tailscale, incl. pushing the existing `Notification`/`Stop`
  hooks to the phone via ntfy (`scripts/claude-attention.sh` is sway/mako-only, so
  it's silent over SSH). **Nothing applied.**

## Home server (HP Spectre x360, 2016)
- Open/optional: `server/README.md` — plan to make an old HP Spectre x360 an
  always-on home server on NixOS + Tailscale. **Nothing applied.**
- **The flake exists and builds (2026-11-07), but has never booted.**
  `server/flake.nix` + `server/hosts/maman/` (nixos-26.05 + disko) pass
  `nix build …#nixosConfigurations.maman.config.system.build.toplevel` on
  the XPS. `hardware.nix` is **hand-written and provisional**; the install
  regenerates it on the machine.
- **Hostname `maman`** (after Meursault's mother in *L'Étranger*), decided
  2026-11-07. **Windows is to be wiped** along with Manjaro; nobody needs it.
- **Unlike the XPS, an agent can `sudo` on `maman`: passwordless for `trc`, by
  design (2026-11-07)**, so Claude Code administers it over SSH. Deploy from
  the XPS with `nix run --inputs-from ~/dotfiles/server nixpkgs#nixos-rebuild --
  switch --flake ~/dotfiles/server#maman --target-host trc@maman --sudo`
  (checked: `--sudo` is the 26.05 flag; `--use-remote-sudo` is gone). **Cost,
  accepted: the XPS key is root there, so OpenClaw must never run as `trc`.**
- **Gotcha: the XPS has no Tailscale yet, and `maman`'s SSH is tailnet-only.**
  Install it on the XPS before the wipe or nothing here can reach the server.
  The phone needs its SSH key in `authorizedKeys` too.
- **One source of truth: `main` on GitHub.** Pull before deploying, push after;
  a stale checkout silently rolls back the other side's deploy. Check what's
  live with `nixos-version --configuration-revision` on `maman`.
- **The machine is reachable now as `ssh server`** (`theodorc@192.168.0.102`,
  Manjaro, hostname `old-disco`, wifi). Passwordless `sudo` is not set up there.
- **Measured 2026-11-07, older than first assumed:** a **late-2016 `13-ac0XX`**,
  i7-7500U **2C/4T**, **8 GB** soldered, 512 GB Samsung PM961, HD 620, no dGPU,
  no wired NIC, **BIOS F.20 of 2016-12-01**, Secure Boot already off, keyboard
  Norwegian. **Windows (335 GB) and Manjaro share the disk**, and the install
  wipes both.
- **Gotcha: the battery reports nothing usable.** `cycle_count 0` and
  `charge_full == charge_full_design` is the firmware not reporting, not a new
  cell. No charge limit in sysfs either, so it will sit at 100% around the
  clock. The physical swelling check is the only health check.
- **Gotcha: the NixOS installer console is US layout and the installed system is
  `no`.** Run `loadkeys no` before setting the root password, or the password
  typed at first boot won't match.
- **Manjaro's `pcie_aspm=off` is a no-op; don't carry it over.** The kernel logs
  `ACPI FADT declares the system doesn't support PCIe ASPM`.
- **The server is a separate machine with a separate purpose** — it is not an
  accessory to this laptop, does not back it up, and is not monitored with it.
  `server/` holds the plan, `inventory.sh`, and **the machine's own flake**.
- **Deliberately not a host inside `nix/`.** `nix/` is an unbuilt draft for a
  laptop that doesn't exist; a headless server shares almost nothing with a Sway
  workstation, and separate `flake.lock`s mean an update can't break both.
  **Gotcha: Nix does *not* enforce the split** — it copies the whole repo, so a
  subdir flake can `import ../…` (tested 2026-11-07). It's a rule. **Read
  `nix/modules/` for ideas, import none of it.**
- **Traps if you copy from `nix/modules/`:** `security.nix` sets
  `services.openssh.enable = false` as a *plain* definition (not `mkDefault`), so
  enabling it elsewhere is a conflicting-definition error; `common.nix` drags in
  the whole desktop and `services.nix` enables CUPS + Avahi; `nix-daemon.nix` is
  tuned for 16 cores, not four.
- **Decided 2026-09-22: no disk encryption.** An encrypted root means no
  unattended reboot after a power cut, which is most of the point. btrfs stays
  (snapper + btrbk); TPM2 enrolment and initrd unlock are moot. Consequences:
  anything stored there is in the clear, and **the Tailscale node key is on that
  disk** — scope the node with tailnet ACLs. Outbound restic keeps its repo
  encrypted client-side, which is what makes an unencrypted server safe to back
  up from.
- **Decided 2026-09-22: the middle path — NixOS base, containers for apps.** Nix
  owns boot/disks/users/sshd/Tailscale/firewall/systemd units **and their
  hardening**; upstream images own Immich, Jellyfin, Paperless, via
  `virtualisation.oci-containers` (Podman) with **pinned tags, never `:latest`**.
  Two deliberate update paths: `nixos-rebuild` moves the base, an image bump
  moves one app. **Recorded so it isn't re-argued:** Debian + Compose is what most
  home servers are and is a fair answer; NixOS earns its keep here for *rollback
  on a headless box* and for cheap systemd hardening, not for purity.
- **The rule that keeps a mixed setup honest:** everything imperative lives under
  one directory, is in the backup path, and has its exact install command written
  down. Same discipline as the in-place `/etc` edits elsewhere in this file.
- **OpenClaw is installed imperatively under a Nix-declared hardened unit**, and
  it's the *last* phase, not a Tier 2 afterthought. It self-updates and installs
  ClawHub skills at runtime, which fights an immutable store — hence the official
  Nix docs being Home Manager-shaped and the community flakes being rough. Nix
  owns the user, unit, `ReadWritePaths` allowlist and firewall; npm owns the bytes.
  `programs.nix-ld` is required (prebuilt Node + native npm modules).
- **Gotcha that inverts the usual reasoning: the firewall does not protect
  OpenClaw's prompt surface.** It connects *outbound* to WhatsApp/Telegram, so
  messages from arbitrary people reach the agent however tight the tailnet is —
  Tailscale protects the control plane, not against prompt injection or a
  malicious skill. Also: `exec` runs **on the host**, "elevated" tools run on the
  host even when sandboxed, and a documented bypass had `/tools/invoke` ignoring
  sandbox tool policies. **Don't co-locate it with Vaultwarden, the backup repo or
  Immich's library.** Containerising it sandboxes `exec` — which also stops it
  restarting services or writing to the vault; **the container's mounts are the
  tool policy.**
- **A laptop server's real enemies are the lid and the battery**, in that order:
  disable the sleep/suspend/hibernate targets outright (not just `logind`), and
  **physically inspect a 6–7 year old cell for swelling** before trusting it to
  run unattended. Leave the lid *open* — free once the switch is ignored, better
  for the hinge vents.
- **Gotcha that presents as a network fault months later:** Tailscale node keys
  expire after 180 days by default. Disable expiry for this node in the admin
  console. And never make Tailscale SSH the *only* way in — a broken `tailscaled`
  takes it with it; run a real sshd bound behind `trustedInterfaces`.
- **Track stable nixpkgs here, not unstable** (the opposite of `nix/flake.nix`, on
  purpose): 2016 hardware needs no new kernel, and `system.autoUpgrade` against
  unstable on the always-on box turns a breaking change into a 4 a.m. outage.
- **`server/INSTALL.md` is the Phase 1 runbook**: USB, data rescue (and the
  **optional** BIOS update) **while Windows still boots**, BIOS setup (the only place to learn
  whether the machine has power-on-after-AC-loss), disko, `nixos-install --flake`,
  first boot (`nmcli` for wifi, then `tailscale up`).
- **Gotcha that wastes the first evening: flakes ignore untracked files.** Edit
  `hardware.nix` in the clone, forget `git add`, and `nixos-install` uses the old
  version or can't find it — and never says why. Also: `nixos-generate-config`
  needs **`--no-filesystems`** when disko owns the layout, or you get two
  conflicting `fileSystems` blocks.
- **The three tests that make it a server, not a laptop:** ssh from the phone **on
  mobile data** (not home wifi — that may be the LAN working); **pull the power
  cord** and it must come back reachable untouched; **close the lid** and it must
  stay up.
- `server/inventory.sh`: run it **on the Spectre** (`ssh server 'bash -s' <
  server/inventory.sh` works; `/sys` only, no root). Results are in the
  README's hardware table.
- Write-up: `server/README.md` — hardware unknowns, the no-encryption decision and
  what it costs, the Tailscale + sshd shape, a ranked menu of services, and a
  5-phase order gated on *nothing gets a service until its data is in the backup
  path*.

## Work project
- Main project is `~/dev/impero`: a **Nix flake dev shell** (`nix develop`), run
  in zellij. .NET runs **inside a Docker container** (`docker compose`), the Rust
  backend via `cargo-watch`, and a Node/TS frontend. rust-analyzer comes from the
  Nix toolchain on `PATH`. Local-only dev overrides go in gitignored files (e.g.
  `docker-compose.override.yml` via `.git/info/exclude`).

## Claude Code
- Config in this repo is `claude/settings.json` and `claude/skills/` (symlinked
  into `~/.claude` by `symlinkifier.pl`). Everything else under `~/.claude/` —
  memory, projects, plans, history — is **state**, not tracked here.
- `CLAUDE.md` is read from the cwd **and every parent dir up to `/`**, so opening
  Claude in `~/dev/impero/backend` already gets the repo-root `CLAUDE.md`. The
  **memory tool** is different: it keys off the *literal cwd*
  (`~/.claude/projects/<slug>/memory/`, slug = abs path with `/ . _` → `-`), so
  each subdir would otherwise start from an empty memory.
- Applied: `scripts/install-claude-memory-links.sh` symlinks impero's subdir
  memory dirs (backend, frontend, frontend/spa, dotnet) at the repo root's, so
  all sessions share one set of facts. Idempotent; re-run for new subdirs or
  after a reinstall. Write-up: `docs/claude-memory-across-subdirs.md`.

## Sway for agents
- **Applied 2026-11-04: `scripts/swayq`**, read-only, compact views of the
  live session: `tree`, `find <regex>`, `outputs`, `inputs`, `whereami`,
  `shot`, `validate`. Not on `PATH`, so call it by full path. The **`sway` skill**
  (`claude/skills/sway/SKILL.md`) says when to use it and what to ask first:
  never `swaymsg reload` (it re-runs every `exec_always`), and ask before focus
  or window changes.
- **Gotcha: under herdr, a session's parent processes never reach a sway
  window.** The chain is `systemd → herdr server → zsh → claude`; the Alacritty
  window holds the herdr *client*. So the lookup has to start from the client
  processes, which `swayq whereami` does. Until 2026-11-04 this silently broke
  `claude-attention.sh`: no urgent flash and no click-to-focus, only the plain
  fallback toast.
- **`claude-attention.sh` now uses `swayq whereami --con`**, keys toasts per herdr
  pane (every session shares one window), prefixes them with the tab label, and
  on click runs `herdr tab focus` before focusing the window. **The click path
  is untested.**
- **Gotcha: `grim` captures only what is on screen.** `swayq shot` refuses a
  window marked `-` (hidden workspace, or behind another tab) instead of
  returning a picture of whatever covers it. Shots go to
  `$XDG_RUNTIME_DIR/swayq/`; titles and screenshots stay out of this public repo.
- **Decided 2026-11-04: no wtype or ydotool.** wtype types into whatever has
  focus, maybe mid-sentence; ydotool needs a uinput daemon that can inject into
  anything, swaylock included, and Ubuntu ships its old CLI. To trigger a
  binding, run its command directly. Don't re-propose without a concrete need.
- Open: with several herdr clients attached, `whereami` takes the first one
  that owns a window.
- Write-up: none; the usage table and rules are in the skill, and
  `swayq --help` lists the commands.
