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

## Terminal & Shell
- **Terminal**: kitty (config ported from Alacritty); Alacritty also still configured
- **Shell**: zsh (self-contained config, no framework; `.zshrc` sources
  `~/dotfiles/zsh/*.zsh` and builds its own prompt via a `precmd` hook)

## Editor
- **Primary**: Neovim (`$EDITOR` and `$VISUAL` both set to `nvim`)
- Man pages open in Neovim (`MANPAGER=nvim +Man!`)

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

## Work project
- Main project is `~/dev/impero`: a **Nix flake dev shell** (`nix develop`), run
  in zellij. .NET runs **inside a Docker container** (`docker compose`), the Rust
  backend via `cargo-watch`, and a Node/TS frontend. rust-analyzer comes from the
  Nix toolchain on `PATH`. Local-only dev overrides go in gitignored files (e.g.
  `docker-compose.override.yml` via `.git/info/exclude`).
