# Installing NixOS on the Spectre, from a blank disk to an SSH you can reach from your phone

**Status: APPLIED 2026-11-07.** `maman` is installed and reachable as
`ssh trc@maman` over Tailscale; it was driven from the XPS over SSH into the
installer. What was verified on the running system, and what wasn't, is in
*Install record, 2026-11-07* at the end of this file.

This is Phase 1 of `README.md` and nothing more: a machine that boots, stays up,
and is reachable. No apps, no containers, no OpenClaw.

Plan for an evening, most of it waiting on downloads.

---

## What you need

| | |
|---|---|
| A USB stick | 4 GB is plenty; its contents will be destroyed |
| **Tailscale on the XPS** | **Not installed yet, and required**: SSH on `maman` is open only on the tailnet, so without it the XPS (and Claude Code on it) can't reach the server at all after the wipe. Needs sudo, so run it yourself: `curl -fsSL https://tailscale.com/install.sh \| sh`, then `sudo tailscale up` and `sudo tailscale set --operator=$USER` |
| Network | The machine has **no wired port**. A USB ethernet adapter makes the installer easy; without one it's wifi by hand (Stage 3) |
| Your phone | To approve the Tailscale login, and to prove SSH works from outside |
| ~30 min of attention, plus download time | |

The hostname is **`maman`** (decided 2026-11-07; Meursault's mother in
*L'Étranger*). Manjaro calls the machine `old-disco` until the install.

---

## Stage 0: the config (done)

Already in the repo, and it builds:

| File | What |
|---|---|
| `server/flake.nix` + `flake.lock` | `nixos-26.05` + disko, one host |
| `server/hosts/maman/default.nix` | systemd-boot, no sleep, NetworkManager, Tailscale, sshd on `tailscale0` only, user `trc` with the XPS's key, `console.keyMap = "no"`, zram, GC |
| `server/hosts/maman/disks.nix` | GPT → 1 GB ESP + btrfs subvolumes, no LUKS. The disk id is filled in (`nvme-SAMSUNG_MZVLW512HMJP-000H1_S36ENX0HB49001`) |
| `server/hosts/maman/hardware.nix` | **Provisional**, written from Manjaro's `lspci`/`lsmod`. Replaced in Stage 4 |

Check it still builds before you go (from `~/dotfiles/server` on the XPS):

```bash
nix build --no-link .#nixosConfigurations.maman.config.system.build.toplevel
```

**Commit and push** before the install. The installer clones from GitHub, and
**a flake can't see untracked files** (see Gotchas).

---

## Stage 1: write the USB

Get the **minimal ISO** (console, ~1 GB) from <https://nixos.org/download/>,
"Minimal ISO image", x86_64. Not the graphical one; this is a server.

`sudo` can't be driven from Claude Code, so **run these yourself**:

```bash
# 1. find the stick. Check the SIZE column, twice. This is the destructive step.
lsblk

# 2. verify what you downloaded (the hash is on the download page)
sha256sum nixos-minimal-*-x86_64-linux.iso

# 3. write it. of=/dev/sdX is the DISK, not a partition like /dev/sdX1
sudo dd if=nixos-minimal-*-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## Stage 2: while Windows still boots

Windows is still on the disk (`nvme0n1p3`, 335 GB, labelled `Windows`).
**Decided 2026-11-07: it gets wiped**, so this is the last chance to use it.

1. **Get anything off it that matters.** It's 335 GB that nobody has looked at
   from the Linux side. Same for Manjaro's `/home`.
2. **Optional: update the BIOS.** It's **F.20 from 2016-12-01**, the original.
   NixOS doesn't need a newer one. CPU microcode, the main security fix, is
   loaded by the OS at every boot (`hardware.cpu.intel.updateMicrocode`)
   whatever the BIOS version. What only a BIOS update brings is fixes to the
   firmware itself (e.g. Intel ME), which matter less on a Tailscale-only box.
   **Do it if Windows boots and it's quick; skip it otherwise.** HP's updates for
   this model ship as Windows `.exe` SoftPaqs (HP Support Assistant, or the
   support page for `13-ac0XX`), so after the wipe it means HP's USB recovery
   route instead. On AC, with the battery charged. That HP published newer
   BIOSes for this model, and that one adds a battery-care setting, are **both
   unchecked**.

Then reboot into BIOS setup: **`Esc`** at power-on for HP's menu, **`F10`** for
setup, **`F9`** for a one-time boot menu.

1. **Secure Boot is already off** (the `SecureBoot` EFI variable reads 0,
   checked 2026-11-07). Leave it off; the NixOS ISO won't boot with it on.
2. Confirm the storage mode is **AHCI/NVMe**, not RAID or Intel Optane.
3. Answer one of `README.md`'s open questions: **is there a "Power on after AC
   loss" / "AC Recovery" option?** Only answerable here.

The EFI boot order already lists `USB Drive (UEFI)` first, so the stick should
boot without the menu.

---

## Stage 3: the live session

Boot the stick. **First:**

```bash
sudo loadkeys no
```

The installer console is US layout, and the installed system is Norwegian
(`console.keyMap = "no"`). Skip this and the root password you type in Stage 4
isn't the one you'll type at first boot, for any password with symbols.

Network. With a USB ethernet adapter it just works. On wifi, **use `nmtui`**:
the 26.05 minimal ISO ships NetworkManager (found 2026-11-07). The
`wpa_supplicant` + `wpa_cli` route from older manuals failed there with
`Could not connect to wpa_supplicant: (nil) - re-trying`.

```bash
sudo nmtui            # "Activate a connection", pick the network, type the password
ping -c3 nixos.org
```

To finish the install from the XPS over SSH instead of at this keyboard (the
installer runs sshd; GitHub serves the XPS's public key):

```bash
mkdir -p ~/.ssh && curl -sL https://github.com/TheodorRene.keys > ~/.ssh/authorized_keys
ip -br a              # then from the XPS: ssh nixos@<that address>
```

The inventory was already taken over SSH on 2026-11-07, so it isn't needed
here. **Do look at the battery**: a bottom panel that doesn't sit flat, or a
trackpad that doesn't click normally, means a swollen cell and is a stop-work
condition. The firmware reports no health data, so this is the only check.

---

## Stage 4: partition and install

**Everything on the disk goes here**: Windows, the recovery partition, Manjaro.

```bash
# the config
git clone https://github.com/TheodorRene/dotfiles /tmp/dotfiles
cd /tmp/dotfiles/server

# confirm the disk id matches disks.nix. If udev names it differently here,
# the nvme-eui.002538bb61b5d443 link is the same disk; put that in instead.
ls -l /dev/disk/by-id/ | grep -v part
grep device hosts/maman/disks.nix

# partition + format + mount, declaratively. DESTROYS the disk.
# --inputs-from . runs the disko version flake.lock pins, not whatever is newest
sudo nix --experimental-features "nix-command flakes" \
  run --inputs-from . disko -- \
  --mode destroy,format,mount \
  hosts/maman/disks.nix

# sanity check before going further: / /boot /nix /var /home /srv all mounted?
findmnt -R /mnt

# hardware facts. --no-filesystems because disko already declares them;
# without it you get a second, conflicting fileSystems block.
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/maman/hardware.nix
git diff hosts/maman/hardware.nix     # expect small differences only

# THE STEP EVERYONE FORGETS: a flake cannot see uncommitted changes to
# untracked files
git add -A

sudo nixos-install --flake /tmp/dotfiles/server#maman
```

It asks for a **root password** at the end. Set one you can type at the
physical keyboard; it's the way back in if SSH doesn't work. (`loadkeys no`
from Stage 3 must still be in effect.)

Copy the clone onto the new disk so the generated `hardware.nix` isn't lost
with the live session:

```bash
sudo cp -a /tmp/dotfiles /mnt/home/trc-dotfiles-install
reboot          # pull the USB stick as it goes down
```

---

## Stage 5: first boot, and the three things that prove it worked

Log in at the keyboard as `root`, then:

```bash
passwd trc                               # needs one for local login and sudo
nmcli device wifi connect "YOUR-SSID" --ask   # skip on ethernet
tailscale up                             # prints a URL; approve it on your phone
tailscale status                         # should show the node with an address
```

In the Tailscale admin console: **disable key expiry for this node.** The
180-day default will otherwise silently drop the server off the tailnet months
from now, and it will present as a network fault.

Put the config somewhere permanent, owned by `trc`:

```bash
mv /home/trc-dotfiles-install /home/trc/dotfiles && chown -R trc: /home/trc/dotfiles
```

Now prove the three properties that make it a server rather than a laptop:

| # | Test | Why it's the test |
|---|---|---|
| 1 | `ssh trc@maman` **from your phone on mobile data**, not the home wifi. **Needs the phone's SSH public key in `authorizedKeys`** (`default.nix`) first, or it's refused | Proves the tailnet, not the LAN |
| 2 | **Pull the power cord, wait, plug it back in.** It must return to a reachable SSH with nobody touching it | With a battery, a short cut is invisible. A long one drains it, and whether it powers back on depends on the BIOS answer from Stage 2 |
| 3 | **Close the lid.** It must stay up | Proves both halves of the sleep config |

Then push `hardware.nix` back so the repo describes the real machine (from the
XPS is easiest: `scp` it over and commit there).

After this, physical access is optional. On the server itself:
`sudo nixos-rebuild switch --flake ~/dotfiles/server#maman`. Or from the XPS,
which builds on 16 cores and copies the result over (no NixOS needed there,
just Nix; `--inputs-from` pins `nixos-rebuild` to the flake's own nixpkgs):

```bash
nix run --inputs-from ~/dotfiles/server nixpkgs#nixos-rebuild -- \
  switch --flake ~/dotfiles/server#maman --target-host trc@maman --sudo
```

Use `test` instead of `switch` for anything touching networking, the firewall
or Tailscale: a power cycle undoes it.

**One source of truth: `main` on GitHub.** Edit anywhere (the XPS, or Claude
Code on the server), but `git pull --ff-only` before every deploy and push
after. Deploying from a stale checkout silently rolls back whatever the other
one deployed. The guard: every generation records its commit, so
`nixos-version --configuration-revision` on the server shows what's live (a
`-dirty` suffix means uncommitted changes went out); compare it with
`git log -1` before deploying.

**From here an agent can take over.** `trc` has passwordless sudo (decided
2026-11-07, see `README.md`), so Claude Code on the XPS can run both commands
above over SSH. Add a `Host maman` / `User trc` entry to the XPS's
`~/.ssh/config`; the old `Host server` entry (`theodorc@192.168.0.102`) stops
working at the wipe, since SSH isn't open on the LAN any more.

---

## Gotchas

- **Watchdog**: after the install, `ls /dev/watchdog0` should exist (likely
  `iTCO_wdt` on this chipset; not checked). If it doesn't,
  `RuntimeWatchdogSec` does nothing and a hang still needs the power button.

- **Flakes ignore untracked files.** Edit `hardware.nix`, forget `git add`, and
  `nixos-install` silently uses the old version, or fails to find the file at
  all. The error message never says "you forgot to git add". Inside the clone,
  `git add -A` before every install or rebuild.
- **The installer is US layout, the installed system is Norwegian.** `loadkeys
  no` before setting any password.
- **No network after first boot, on wifi.** The installer's wifi setup
  doesn't carry over; NetworkManager needs `nmcli device wifi connect`
  once, at the keyboard. Until then there's no `tailscale up` and no SSH.
- **SSH is not reachable on the LAN, by design** (`openFirewall = false`, only
  `tailscale0` is trusted). Before `tailscale up`, the keyboard is the only way in.
- **`nixos-generate-config` without `--no-filesystems`** emits a `fileSystems`
  block that fights disko's. Two definitions, one error, confusing message.
- **`/dev/nvme0n1` in `disks.nix`**: kernel names are not stable across boots.
  Use `/dev/disk/by-id/...`.
- **A 512 MB ESP** fills up after a handful of generations, and generations are
  the rollback plan. 1 GB.
- **`system.stateVersion`** is not a version to keep current. Set it once at
  install and never touch it again.
- **26.05 is supported until the end of 2026.** Bump the `nixpkgs` input to
  `nixos-26.11` once it's out; `stateVersion` stays `26.05`.
- **Don't test SSH from the home wifi and call it done.** That may be working
  over the LAN. Mobile data is the real test.

## Not used, and why

- **nixos-anywhere** (install over SSH from the XPS, no USB stick): it kexecs
  into an installer that carries over wired network config, not wifi
  credentials, and needs root on the target. With a USB ethernet adapter
  plugged in it would be an option; on wifi the stick is simpler.
- **`pcie_aspm=off`**: Manjaro's kernel command line has it, but the firmware's
  FADT already disables ASPM (`ACPI FADT declares the system doesn't support
  PCIe ASPM` in the kernel log), so it does nothing. Not carried over.

## If it goes wrong

The same USB stick is the rescue disk. Boot it, then:

```bash
git clone https://github.com/TheodorRene/dotfiles /tmp/dotfiles && cd /tmp/dotfiles/server
sudo nix --experimental-features "nix-command flakes" run --inputs-from . disko -- \
  --mode mount hosts/maman/disks.nix
sudo nixos-enter --root /mnt          # a shell inside the installed system
```

From there you can edit the config and `nixos-rebuild boot` without reinstalling.

If the system boots but is broken, you don't need the USB at all: **pick an
older generation in the boot menu.** That's what `configurationLimit = 10` is
for.

## Reversing it

There is no undo: Stage 4 destroys Windows and Manjaro. Reversal means
reinstalling from their own media. That's why Stage 2 is about getting data off
first.

## What's next

`README.md`'s Phase 2: the external disk, snapper + btrbk, and restic to
somewhere offsite, **and a restore actually performed**, because an untested
restore isn't a backup. Nothing that stores data gets installed before that.

---

## Install record, 2026-11-07

How it actually went, so the next reinstall knows where the edges are.

- **The USB stick wasn't booted at first.** The firmware saw it (it added
  `Boot0006`/`Boot0007`, "USB Drive (UEFI) - VendorCo ProductCode") but put
  those entries **last**, behind Manjaro. Fixed from the running Manjaro with
  `sudo efibootmgr --bootnext 0006 && sudo reboot`. Esc → F9 at power-on is the
  other way; the menu timeout is 0, so press Esc before the logo.
- **Wifi in the installer: `nmtui`**, not `wpa_cli` (see Stage 3).
- **Driving it remotely:** `curl https://github.com/TheodorRene.keys >
  ~/.ssh/authorized_keys` in the installer, then `ssh nixos@<ip>`. The ISO has
  `screen` but no `tmux`; `screen -dmS install` + `screen -x install` on the
  console showed every command live on the Spectre's screen.
- **`--no-root-passwd` would have locked everyone out.** No root password, `trc`
  has none yet, and SSH is tailnet-only, so nobody could log in to run
  `tailscale up`. The root password was typed at the Spectre's keyboard.
- The generated `hardware.nix` matched the hand-written one in substance (same
  initrd modules, `kvm-intel`, microcode).
- **First deploy from the XPS worked** (`--target-host trc@maman --sudo`).

Verified on the running system (`ssh trc@maman`, same day):

| Check | Result |
|---|---|
| Failed units | none |
| sleep / suspend / hibernate / hybrid-sleep | all `masked` |
| logind `HandleLidSwitch`, `…ExternalPower` | `ignore`, `ignore` |
| Watchdog | systemd armed **`intel_oc_wdt`** (`/dev/watchdog0`) at 30 s; `iTCO_wdt` is `/dev/watchdog1`. **Neither proven to reset the machine.** One attempt was invalid: the process holding `/dev/watchdog1` exited at once, and the kernel then keeps pinging a running watchdog nobody holds (`watchdog did not stop!`, `timeleft` stuck at 30). A real test needs a holder that stays alive, e.g. `sudo sh -c 'exec 3>/dev/watchdog1; exec /run/current-system/sw/bin/sleep 600'` |
| `kernel.panic` | 10 |
| upower | **was `inactive`** (its unit is `WantedBy=graphical.target`); fixed with `wantedBy = [ "multi-user.target" ]`, now active, battery 79% |
| smartd, thermald, sshd, tailscaled, NetworkManager | active |
| btrfs scrub timer | monthly, first run 2026-12-01 |
| Firewall | `tailscale0` accepted, UDP 41641 open, nothing else |
| Wifi power save | off (`wifi.powersave=2`) |
| Memory at idle | 531 MB used of 7.6 GB; zram 3.8 GB |
| Disk | `/` 2.3 GB used of 476 GB; `/boot` 55 MB of 1 GB |

**Not done yet:** the lid-close and power-cord tests, and SSH from the phone on
mobile data (needs the phone's key in `authorizedKeys`).

Harmless noise in `journalctl -b -p err`: `ACPI BIOS Error (bug):
AE_AML_BUFFER_LIMIT … \_SB.WMID.WQBE` (the 2016 HP firmware's WMI tables),
`dbus-broker-launch … Ignoring duplicate name`, and a Bluetooth `Reading
supported features failed (-16)`.

**`-dirty` on `nixos-version --configuration-revision` doesn't mean the server
config was dirty.** `dirtyRev` covers the whole dotfiles repo, so any
uncommitted edit anywhere (herdr, sway) makes a deploy from the XPS show it.
