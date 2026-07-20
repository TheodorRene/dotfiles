# Ubuntu Reinstall Guide

Follow top to bottom in three phases:

1. **Before** — on the *current* system, save everything that isn't reproducible.
2. **During** — the installer: partitioning + encryption.
3. **After** — first boot on the fresh system: rebuild, install, restore.

Machine: Dell XPS 14 (DA14260), Ubuntu + Sway/Wayland. Encrypted dual-boot with
Windows.

---

# Part 1 — Before (on the current system)

Do all of this while the old install is still bootable. Copy backups to an
**external drive or another machine** — anything left on the internal disk dies.

## 1.1 Make the install USB

Download the Ubuntu ISO, then write it to a USB stick (find the device with
`lsblk` first — **double-check the target, `dd` is unforgiving**):

```bash
# e.g. sudo dd if=~/Downloads/ubuntu-26.04-desktop-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
lsblk    # identify the USB as /dev/sdX (NOT nvme0n1 — that's your disk)
```

## 1.2 Push all git work

Nothing local survives — push every repo, and eyeball what's still unpushed/dirty:

```bash
for d in ~/dotfiles ~/dev/*/; do [ -d "$d/.git" ] && \
  echo "$d: $(git -C $d log --oneline --branches --not --remotes | wc -l) unpushed, \
$(git -C $d status --porcelain | wc -l) dirty"; done
```

## 1.3 Copy out everything NOT in git

These live only on this disk — back each one up:

| What | Path | Notes |
|---|---|---|
| SSH keys | `~/.ssh/` | |
| GPG keys | `~/.gnupg/` | |
| Claude Code state | `~/.claude/` | memory, projects, plans — not in dotfiles |
| Wallpapers | `~/wallpapers/` | swaylock/swaybg need them |
| Nerd Fonts | `~/.local/share/fonts/` | or re-download later (§3.5) |
| Firefox profile | `~/snap/firefox/common/.mozilla/firefox/` | **Close Firefox first** (sqlite DBs must be quiescent), else `places`/`cookies` may need recovery. **snap path** while Firefox is a snap. Includes saved passwords (`logins.json` + `key4.db`). Restore into `~/.mozilla/firefox/` (§3.6). |
| impero local files | `~/dev/impero/` | gitignored, in no remote — see the `impero-local.tar.gz` command below |

### What was actually backed up (reference)

The USB auto-mounts root-owned (FAT32), so make it writable first — this is a
mount-option change only, it does **not** reformat or touch existing files:

```bash
sudo mount -o remount,uid=$(id -u),gid=$(id -g) /mnt/usb   # if remount is ignored: sudo umount, then sudo mount -o uid=$(id -u),gid=$(id -g) /dev/sdX1 /mnt/usb
```

**impero local config + secrets** → `impero-local.tar.gz`. Includes env/MCP/Claude
config and, importantly, the local dev **TLS certs + private keys** under
`backend/dev_data/` (SMTP `noreply` + `ca`, nginx cert/key) which are gitignored:

```bash
tar czf /mnt/usb/impero-local.tar.gz -C ~/dev/impero --ignore-failed-read \
  .env .mcp.json CLAUDE.md docker-compose.override.yml \
  .claude/settings.local.json backend/.claude/settings.local.json \
  frontend/.claude/settings.local.json \
  backend/dev_data tools/impero/.dev_session_cookies
```

**Everything except `~/dev`** → `trc-home.tar.gz.part-*` (split tar; see §1.4).

Not backed up (regenerable / re-clonable): `~/dev` build artifacts, the nested
`dotnet/` and `product-wiki/` git repos (re-clone them), playwright profiles,
generated frontend assets.

If your dev Postgres holds state you care about, also dump it — Docker volumes die
with the disk:

```bash
docker compose exec -T <db-service> pg_dumpall -U postgres > ~/impero-db-backup.sql
```

## 1.4 Optional: bulk backup of everything except ~/dev

If you want more than the targeted list in §1.3, back up all of `~` **except
`~/dev`** — dev is ~90% of the disk and is either pushed to remotes or
regenerable (node_modules, Rust `target/`, Docker data). That's ~24 GB, or ~11 GB
if you also skip regenerable caches (`.cache`, `.npm`, `.nvm`, `.cargo`,
`.local/share/{bob,nvim}`).

**FAT32 gotchas** (default for most USB sticks): it can't store symlinks or Unix
permissions, and caps files at 4 GB — so don't naive-`cp` (it breaks `~/.config`
symlinks into dotfiles and `~/.ssh` perms). Two working options:

**A — split tar** (keeps perms/symlinks inside the archive; parts stay <4 GB):

```bash
# FAT32 sticks often auto-mount root-owned; make it writable first:
sudo mount -o remount,uid=$(id -u),gid=$(id -g) /mnt/usb

tar czf - -C ~ --exclude=./dev \
  --exclude=./.cache --exclude=./.npm --exclude=./.nvm --exclude=./.cargo \
  --exclude=./.local/share/bob --exclude=./.local/share/nvim . \
  | split -b 3900M -d - /mnt/usb/trc-home.tar.gz.part-

# restore later:
cat /mnt/usb/trc-home.tar.gz.part-* | tar xzf - -C <dest>
```

**B — reformat the stick to ext4** (no limits, preserves everything, browsable):

```bash
sudo umount /mnt/usb && sudo mkfs.ext4 -L backup /dev/sdX1
sudo mount /dev/sdX1 /mnt/usb && sudo chown $USER:$USER /mnt/usb
rsync -aH --info=progress2 --exclude=dev ~/ /mnt/usb/home/
```

## 1.5 Note extra apt repos to re-add later

Beyond what §3.5 installs, this machine also had: **signal-desktop, dbeaver-ce,
solaar, mozillateam PPA**. Jot down any others from `ls /etc/apt/sources.list.d/`.

## 1.6 Dual-boot / BitLocker

Reinstalling GRUB touches the shared EFI partition. If Windows has **BitLocker**
enabled, have the recovery key ready (it can prompt on next Windows boot).
*Currently not enabled here — the Windows partitions are plain NTFS.*

---

# Part 2 — During (the installer)

Boot from the USB → **Try Ubuntu** → launch installer → **Manual partitioning**.

## 2.1 Partitioning (encrypted dual boot)

| Partition | Type | Mount | Action |
|---|---|---|---|
| Windows EFI | FAT32 | `/boot/efi` | Keep — do NOT format |
| Windows C: | NTFS | — | Leave untouched |
| Free space | ext4 + LUKS | `/` | Create new, enable encryption |

Select free space → Add → type **Physical Volume for Encryption** → set
passphrase → format inside as ext4 → mount as `/`. GRUB installs to the existing
EFI partition automatically.

Encryption notes:
- The swapfile and zram live inside the LUKS root — nothing extra to encrypt.
- TRIM through LUKS: after boot, check `lsblk --discard` shows nonzero DISC-GRAN
  for the crypt device; if not, add `discard` to its line in `/etc/crypttab`
  (recent installers do this already). `fstrim.timer` should be enabled.

## 2.2 Optional: TPM auto-unlock (skip the passphrase)

Store the LUKS key in the TPM so boot doesn't prompt for the passphrase, while
the disk stays encrypted at rest. The TPM only releases the key if the boot
chain is unchanged (bound to PCR 7 = Secure Boot state); tampering falls back to
the passphrase, which always stays enrolled as a fallback keyslot.

**Trade-off:** without a PIN, a thief with the whole powered-off laptop gets an
auto-decrypted disk (still gated by your login password). Adding `--tpm2-with-pin`
requires a short PIN at boot instead of the full passphrase — recommended.

Run these **after first boot** on the installed system (`nvme0n1pN` = the LUKS
partition, find it with `lsblk`):

```bash
systemd-analyze has-tpm2                     # confirm a usable TPM2 is present

# Enroll: bind to Secure Boot state (PCR 7), require a PIN. Prompts for the
# existing passphrase once, then a new PIN.
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/nvme0n1pN

# Tell the initramfs to try the TPM: add `tpm2-device=auto` to the options field
# of the LUKS line in /etc/crypttab, then rebuild.
sudo update-initramfs -u
```

To undo: `sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1pN` and remove
the crypttab option.

---

# Part 3 — After (first boot on the new system)

## 3.1 Basics

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget zsh perl
chsh -s $(which zsh)
```

## 3.2 Dotfiles

```bash
# HTTPS so it works before SSH keys are restored (§3.6); switch the remote to
# SSH later with: git -C ~/dotfiles remote set-url origin git@github.com:TheodorRene/dotfiles.git
git clone https://github.com/TheodorRene/dotfiles.git ~/dotfiles
cd ~/dotfiles && perl symlinkifier.pl
```

## 3.3 System tuning (memory / OOM / boot)

**oomd + zram** — make `systemd-oomd` kill the heaviest cgroup in `user.slice`
on sustained pressure before the kernel OOM killer hard-resets the session.
Symlinks `/etc/systemd/{system/user.slice.d,oomd.conf.d,zram-generator.conf}`.

```bash
~/dotfiles/scripts/install-oomd-tuning.sh
```

**VM sysctls + boot** — tuned for the zram-primary layout (no swap read-ahead,
prefer compressed swap over dropping file cache, keep metadata caches, earlier
kswapd) and disable `NetworkManager-wait-online` (blocks boot ~5s). Symlinks
`/etc/sysctl.d/99-vm-tuning.conf`.

```bash
~/dotfiles/scripts/install-perf-tuning.sh
```

**Swapfile (zram overflow)** — Ubuntu sizes `/swap.img` by its own heuristic;
resize to **8G** to match the design (zram prio 100, disk swap prio -1):

```bash
sudo swapoff /swap.img
sudo fallocate -l 8G /swap.img && sudo chmod 600 /swap.img
sudo mkswap /swap.img && sudo swapon /swap.img   # fstab entry already exists
```

> CPU stays at max responsiveness via power-profiles-daemon
> (`powerprofilesctl set performance`) — no config needed, just verify.

## 3.4 Node (nvm)

The shell needs no framework — `.zshrc` (symlinked in §3.2) is self-contained:
its own `compinit`, a custom `_build_prompt` precmd, and it sources
`~/dotfiles/zsh/*.zsh` directly. `fzf`, `direnv`, and `autojump` (installed in
§3.5) wire themselves in on first prompt. **No oh-my-zsh.**

Install nvm + Node:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
# restart shell, then:
nvm install --lts && nvm use --lts
```

## 3.5 Packages

### apt — Wayland / Sway stack

```bash
sudo apt install -y \
  sway swaybg swaylock swayidle \
  waybar wofi kanshi mako \
  alacritty kitty \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
  wl-clipboard wl-mirror wdisplays wev \
  grim slurp \
  brightnessctl
```

### apt — Audio / Bluetooth

```bash
sudo apt install -y \
  pipewire pipewire-audio wireplumber \
  libspa-0.2-bluetooth \
  pavucontrol playerctl \
  blueman bluez
```

### apt — Display / GPU

```bash
sudo apt install -y \
  mesa-utils vulkan-tools \
  intel-gpu-tools intel-ipu7-dkms \
  vainfo \
  v4l2loopback-dkms v4l-utils \
  kooha
```

### apt — CLI tools

```bash
sudo apt install -y \
  fzf ripgrep eza bat \
  direnv htop tmux mosh \
  just mpv autojump \
  network-manager-gnome
```

### apt — Dev

```bash
sudo apt install -y gh vim
```

### apt — Docker (needs repo first)

```bash
sudo install -m 0755 -d /etc/apt/keyrings   # may not exist on fresh Ubuntu
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

### Firefox (Mozilla repo, not snap)

Fresh Ubuntu ships Firefox as a **snap**; this switches it to the native `.deb`
from Mozilla's repo (faster starts, no snap refreshes). The script adds the repo,
pins it, removes the snap, and installs the deb:

```bash
bash ~/dotfiles/scripts/install-firefox-apt.sh
xdg-settings set default-web-browser firefox.desktop
```

Then restore your profile (§3.6) and verify it's really native:

```bash
dpkg -l firefox | tail -1     # version 1xx.x, NOT "1:1snap1..."
snap list firefox             # should error: no matching snaps
```

### Slack

Download `.deb` from slack.com and install:
```bash
sudo dpkg -i slack-desktop-*.deb
sudo apt install -f  # fix any dependency issues
```

### Snap

```bash
sudo snap install chromium
```

### npm globals

```bash
npm install -g \
  opencode-ai \
  typescript \
  typescript-language-server \
  vscode-langservers-extracted \
  tree-sitter-cli
```

> `bun` installs itself separately: `curl -fsSL https://bun.sh/install | bash`

### Neovim via bob

```bash
# Install bob (neovim version manager). rust/cargo isn't installed system-wide
# (it comes from the Nix impero shell), so grab the prebuilt binary:
#   download from github.com/MordechaiHadad/bob/releases -> ~/.local/bin/bob (chmod +x)
# or, only if you already have cargo on PATH: cargo install bob-nvim

bob install v0.12.2
bob use v0.12.2
```

> `bob` puts the nvim binary at `~/.local/share/bob/nvim-bin/nvim` — already in PATH via `zsh/path.zsh`.

### lazydocker

```bash
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
# binary goes to ~/bin/lazydocker
```

### Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

### Determinate Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### nix-direnv (fast flake dev shells)

Caches `nix develop` environments so `cd ~/dev/impero` loads warm (~50 ms)
instead of re-evaluating the flake. The direnv config (`~/.config/direnv`) is
already symlinked by `symlinkifier.pl`; only the package install is manual:

```bash
nix profile install nixpkgs#nix-direnv
```

### JetBrainsMono Nerd Font

Restore from backup (§3.6) or re-download from nerdfonts.com → JetBrainsMono,
into `~/.local/share/fonts/`, then:
```bash
fc-cache -fv
```

## 3.6 Restore backed-up files

Copy back what you saved in §1.3:

| What | Restore to |
|---|---|
| SSH keys | `~/.ssh/` (`chmod 600` the private keys) |
| GPG keys | `~/.gnupg/` then `chmod 700 ~/.gnupg && chmod 600 ~/.gnupg/*` |
| Claude Code state | `~/.claude/` |
| Wallpapers | `~/wallpapers/` |
| Nerd Fonts | `~/.local/share/fonts/` → `fc-cache -fv` |
| Firefox profile | see the dedicated steps below |
| impero local files | after cloning impero: `tar xzf /mnt/usb/impero-local.tar.gz -C ~/dev/impero` |
| Postgres dump | `docker compose exec -T <db> psql -U postgres < ~/impero-db-backup.sql` |

For the bulk archive (§1.4), extract with:

```bash
cat /mnt/usb/trc-home.tar.gz.part-* | tar xzf - -C ~   # everything-but-dev
```

### Firefox profile (snap backup → apt Firefox)

The backup holds the profile under the **snap** path
`snap/firefox/common/.mozilla/firefox/`; native apt Firefox reads
`~/.mozilla/firefox/`. After installing apt Firefox (§3.5) and with Firefox
**closed**:

```bash
# The bulk archive (extracted above) put the profile here:
SRC=~/snap/firefox/common/.mozilla/firefox
mkdir -p ~/.mozilla/firefox
cp -a "$SRC"/. ~/.mozilla/firefox/        # copies all profiles + profiles.ini + installs.ini
```

The main profile is `p0t8fdxe.default-release-1` (has `logins.json` = saved
passwords, decrypted by `key4.db` in the same dir — keep them together). If
Firefox opens a blank profile, go to `about:profiles` and "Set as default
profile" on that folder, or edit `~/.mozilla/firefox/profiles.ini` so the
`Default=` path points at it. Saved passwords survive only if `key4.db` and
`logins.json` are both restored.

Then clone impero and its nested repos, re-add extra apt repos (§1.5), and set up
hosts:

```bash
git clone git@github.com:impero-com/impero.git ~/dev/impero
# nested, gitignored repos:
git clone git@github.com:impero-com/impero_legacy.git       ~/dev/impero/dotnet
git clone git@github.com:impero-com/Impero-product-wiki.git ~/dev/impero/product-wiki
cd ~/dev/impero && just add_hosts   # writes the IMPERO-HOSTS block to /etc/hosts
```

## 3.7 Post-install checks

- [ ] Waybar appears at bottom of screen
- [ ] `$mod+Return` opens Alacritty
- [ ] `$mod+d` opens Wofi
- [ ] `$mod+o` opens Firefox
- [ ] Audio keys work
- [ ] Brightness keys work
- [ ] `Print` (region screenshot) and `Shift+Print` (full) copy to clipboard
- [ ] Kanshi detects external monitor and switches profiles automatically
- [ ] `$mod+Shift+u` switches to laptop-only output
- [ ] `$mod+b` locks with swaylock + wallpaper (needs `~/wallpapers/`)
- [ ] Docker works without sudo (may need re-login after `usermod`)
- [ ] `node --version` works in a fresh shell
- [ ] `cd ~/dev/impero` loads the direnv devshell fast (nix-direnv cached)
- [ ] `swapon --show` shows zram at prio 100, `/swap.img` at -1
- [ ] `firefox --version` is the deb build, not snap
