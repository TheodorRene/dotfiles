# Ubuntu → NixOS: what maps to what

Read alongside `REINSTALL.md`. Sections marked **gone** mean the manual step
disappears entirely.

## The repo's own machinery

| Ubuntu | NixOS |
|---|---|
| `symlinkifier.pl` | `nix/home/dotfiles.nix` (`mkOutOfStoreSymlink`, same 20 paths) — **the Perl script still works**, they just fight over the same targets |
| `scripts/install-oomd-tuning.sh` | `modules/memory.nix` (`zramSwap`, `systemd.oomd`) — **gone** |
| `scripts/install-perf-tuning.sh` | `modules/memory.nix` (`boot.kernel.sysctl`) + `modules/networking.nix` (wait-online) — **gone** |
| `scripts/install-gdm-autologin.sh`, `etc/gdm3/custom.conf` | `services.displayManager.autoLogin` — **gone** |
| `scripts/install-firefox-apt.sh` (repo + key + pin + de-snap) | `programs.firefox.enable = true` — **gone** |
| `scripts/install-yubikey-sudo.sh` (PAM surgery) | `security.pam.u2f` + `security.pam.services.sudo.u2fAuth`; the `pamu2fcfg` tap stays manual |
| `scripts/install-claude-memory-links.sh` | unchanged — it manages `~/.claude` state, which no config should own |
| `dependencies.sh` (a stale `pacman` list) | `modules/packages.nix` + `home/packages.nix` |
| `REINSTALL.md` §2.1's manual partitioning + `mkfs` | `hosts/newhost/disks-disko.nix` — one `disko` run, no transcribed UUIDs (scoped to two partitions so the dual-boot ESP and NTFS volumes are out of reach) |
| `just add_hosts` writing `/etc/hosts` | `networking.hosts` in `modules/networking.nix` — `/etc/hosts` is generated, so the imperative version can't stick |

## Packages

Everything in `REINSTALL.md` §3.5 is covered except where noted.

| apt | nixpkgs |
|---|---|
| `sway swaybg swaylock swayidle waybar wofi kanshi mako-notifier` | `programs.sway.extraPackages` |
| `xdg-desktop-portal{,-gtk,-wlr}` | `xdg.portal` + `wlr.enable` |
| `wl-clipboard wl-mirror wdisplays wev grim slurp brightnessctl` | same names (`wlr-randr` added) |
| `pipewire pipewire-audio wireplumber libspa-0.2-bluetooth` | `services.pipewire` (bluetooth backend is built in) |
| `mesa-utils` / `vainfo` | `mesa-demos` / `libva-utils` |
| `v4l2loopback-dkms` | `boot.extraModulePackages = [ kernelPackages.v4l2loopback ]` |
| `intel-ipu7-dkms` | **no equivalent** — `hardware.ipu6` is IPU6-only; webcam likely dead |
| `bat` → binary `batcat` | `bat` → binary `bat`; a `batcat` shim is in `modules/packages.nix` so `alias cat="batcat"` keeps working |
| `bfs`, `eza`, `just`, `mosh`, `autojump`, `fzf`, `ripgrep`, `direnv`, `mpv`, `htop`, `gh` | same names |
| `plocate` | `services.locate.package = pkgs.plocate` |
| `docker-ce` + `docker-compose-plugin` | `virtualisation.docker` + `docker-compose`, `docker-buildx` |
| lazydocker via `curl | bash` | `pkgs.lazydocker` |
| Slack `.deb` | `pkgs.slack` (unfree — allowed in `modules/nix-daemon.nix`) |
| `snap install chromium` | `pkgs.chromium`; **no snapd at all** |
| JetBrainsMono Nerd Font by hand + `fc-cache` | `fonts.packages = [ nerd-fonts.jetbrains-mono ]` |
| Determinate Nix installer | the system's own `nix.settings` |
| `nix profile install nixpkgs#nix-direnv` | `home/packages.nix`; the repo's `direnv/direnvrc` already sources it from `~/.nix-profile` — unchanged |

## Things that behave differently

**Prebuilt binaries need `nix-ld`.** `programs.nix-ld.enable = true` is set, which
is what makes the following still run at all:

| Tool | Works via nix-ld? | Better on NixOS |
|---|---|---|
| `nvm` + Node tarballs | yes | `nodejs_22` from nixpkgs; `.zshrc` still sources `~/.nvm/nvm.sh` when present, so `nvm use` still wins on PATH |
| `bob` (neovim manager) | yes | `pkgs.neovim`; drop `~/.local/share/bob/nvim-bin` from `zsh/path.zsh` if you stop using bob |
| `bun` self-install | yes | `pkgs.bun` |
| `fff.nvim`'s downloaded Rust binary | yes | `cargo`/`rustc` are in `home/packages.nix`, so the build fallback works without entering the impero devshell |
| `tree-sitter-cli` via npm | yes | `pkgs.tree-sitter` — still mandatory, or hover code blocks stay unstyled (`nvim_v2/SETUP.md`) |
| `~/.dotnet` SDK | yes (icu/openssl/krb5 in `nix-ld.libraries`) | irrelevant here: .NET runs in Docker |

**`claude-code`** is in `home/packages.nix`, but it self-updates, and it can't
write into `/nix/store`. If the built-in updater matters more than pinning, drop
the package and `npm install -g @anthropic-ai/claude-code` into
`~/.npm-packages` instead (already on `PATH` via `zsh/path.zsh`, and it runs
under `nix-ld`).

**`sudo` cannot be run from a Claude session here** (`CLAUDE.md`) — that doesn't
change. `nixos-rebuild switch` is a command to hand over, not to run.

**`/etc` is generated.** Anything that appends to a file under `/etc` — the
YubiKey PAM line, `just add_hosts`, `install-firefox-apt.sh`'s apt pin — either
has a NixOS option (used above) or won't survive a rebuild.

**Rollbacks are real.** A bad rebuild is one GRUB entry away from undone, and
with btrfs, a bad *user-level* mistake is one `snapper` command away
(`backup-and-recovery.md`). That's the main thing this migration buys beyond
reproducibility.

## Deliberate improvements over the Ubuntu setup

- Swapfile sizing (`REINSTALL.md` §3.3's `fallocate`/`mkswap` dance) is
  declared; on btrfs NixOS even uses `btrfs filesystem mkswapfile`.
- The disk layout itself is in git (disko), so "how was this partitioned?" has an
  answer that can't drift from reality.
- `video`/`input` group membership is declared, so brightness keys work on the
  first boot instead of after the `usermod` + re-login gotcha.
- oomd's *per-slice* pressure limit is pinned to 60%: NixOS' own module defaults
  it to 80% on `user.slice`, which would have silently overridden the 60% the
  Ubuntu config chose.
- `services.btrfs.autoScrub`, `services.fstrim`, `services.thermald`,
  `services.chrony` and persistent journald are on by declaration rather than by
  remembering.
