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
- Open/optional: `docs/nordic-letters-on-us-layout.md` — plan to get æøå on a US
  layout (`us(altgr-intl)` + three Oryx remaps), **not applied**; the layout's
  current Nordic keys are dead and `grp:alt_shift_toggle` is still in place. Also
  holds a layer-by-layer cheat sheet of the layout as of 2026-08-03.

## Terminal & Shell
- **Terminal**: kitty (config ported from Alacritty); Alacritty also still configured
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

## Boot / disk
- Root is **LUKS-encrypted**: `nvme0n1p8` (LUKS) → `dm_crypt-0` → `ubuntu-vg/ubuntu-lv`
  → `/`. So an initramfs complaining `/dev/ubuntu-vg/ubuntu-lv does not exist` is
  **not an LVM fault** — it means the LUKS unlock never completed.
- Initramfs is **dracut** (systemd-based), *not* initramfs-tools — the latter isn't
  installed, so most Ubuntu advice and its knobs don't apply. `rdsosreport.txt` is
  dracut's emergency dump.
- Happened once (2026-08-05, fixed by a reboot). Hardware ruled out; **cause not
  established** — three theories were built and killed by later evidence, so read
  the write-up before theorising. What *is* solid: the ~90s hang matches
  `DefaultDeviceTimeoutUSec`, so the **LV device job** timed out, not the passphrase
  step (`systemd-cryptsetup` has `TimeoutSec=infinity`).
- If it recurs, **run `ls /dev/mapper/` first** — `dm_crypt-0` present means an LVM
  activation failure, absent means the unlock never happened. That datum is
  unrecoverable afterwards (`/run` is tmpfs, and a failed boot leaves no journal).
- Write-up: `docs/luks-boot-emergency-shell.md` — symptom record, verified mechanics
  (incl. the trap that `rd.lvm.lv` **is** set via `hostonly_cmdline` inside the
  image, not `/proc/cmdline`), a dead-ends table, in-place recovery without
  rebooting, and candidate grub changes. **Nothing applied.**
- `smartmontools` **is** installed, but `smartctl` (and `tune2fs`) need root:
  `sudo smartctl -a /dev/nvme0n1`.

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

## Remote access
- No SSH server installed (`openssh-server` absent, so no `/etc/ssh/sshd_config`),
  no Tailscale. `mosh` **is** installed (the package is client + server); `tmux`
  and `screen` are in `/usr/bin`, but `zellij` only exists inside the impero nix
  shell.
- Open/optional: `docs/claude-code-from-phone.md` — plan to drive Claude Code from
  a phone over SSH + Tailscale, incl. pushing the existing `Notification`/`Stop`
  hooks to the phone via ntfy (`scripts/claude-attention.sh` is sway/mako-only, so
  it's silent over SSH). **Nothing applied.**

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
