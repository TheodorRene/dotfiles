# Installing on the new machine

Two paths. **A** is the one you want: disko partitions and formats from the Nix
description, so there are no hand-typed `mkfs` commands and no UUIDs to
transcribe. **B** is how `disco` was done, kept for reference and for installing
onto an existing layout you don't want to touch.

Do `REINSTALL.md` **Part 1** first if there's anything on the target disk. This
config can't help you recover data it never saw.

---

# Path A — disko (`hosts/newhost`)

## A1. Make room for it, from Windows

Only Windows' own **Disk Management** reliably shrinks an NTFS volume (it moves
metadata that GParted won't). Shrink `C:` to leave the space you want, then
reboot into the NixOS installer and create **two** partitions in the free space
with `gdisk` / `cfdisk`:

| Size | Type | Becomes |
|---|---|---|
| ~2 GB | Linux filesystem (8300) | `/boot` — unencrypted ext4 |
| the rest | Linux filesystem (8300) | the LUKS container |

`/boot` has to stay outside the container: LUKS2 uses argon2id, which GRUB can't
unlock, so the kernel and initrd must be readable before the unlock happens. 2 GB
because every NixOS generation parks a kernel + initrd there (~120 MB each) —
`modules/boot.nix` caps that at 12 generations for exactly this reason.

Leave the existing ESP and every NTFS partition alone. GRUB installs *into* the
ESP alongside the Windows loader.

## A2. Boot the installer, get the identifiers

Any recent NixOS **minimal or graphical ISO** (`REINSTALL.md` §1.1 for writing
the USB). Then:

```bash
sudo -i
loadkeys us
# network: nmtui, or ethernet
lsblk -f
ls -l /dev/disk/by-id/          # stable names — use these, not /dev/nvme0n1pN
blkid /dev/nvme0n1p1            # the existing ESP's UUID (short, like 3491-D302)
```

## A3. Fill in the three placeholders

```bash
nix-shell -p git --run 'git clone https://github.com/TheodorRene/dotfiles.git /tmp/dotfiles'
cd /tmp/dotfiles/nix
$EDITOR hosts/newhost/disks-disko.nix
```

- `bootPartition` ← the ~2 GB partition, as `/dev/disk/by-id/…-partN`
- `luksPartition` ← the big one, same form
- `espUuid` ← the existing ESP's filesystem UUID

Also rename the host (`README.md`, "Adding the new machine") and set
`local.zramMaxGiB` to about half of this machine's RAM.

**Re-read the device paths before you continue.** disko is scoped to the two
partitions you named — it declares no partition table, so it can't touch the ESP
or the NTFS volumes — but it *will* unconditionally reformat whatever those two
paths point at.

## A4. The LUKS passphrase

disko reads it from a file at install time. This is the passphrase you'll type at
every boot, so pick accordingly:

```bash
(umask 077; printf '%s' 'the passphrase you will actually remember' > /tmp/luks.key)
```

(Or set `askPassword = true;` instead of `passwordFile` in the disko file to be
prompted.)

## A5. Partition, format, mount — one command

```bash
nix --extra-experimental-features 'nix-command flakes' run \
  github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake /tmp/dotfiles/nix#newhost
```

That runs `cryptsetup luksFormat`, `mkfs.btrfs`, creates the `root`/`home`/`nix`/
`var-log`/`snapshots`/`swap` subvolumes, and mounts the whole tree under `/mnt`.
Check it:

```bash
mount | grep /mnt
sudo btrfs subvolume list /mnt
mkdir -p /mnt/boot/efi && mount /dev/nvme0n1p1 /mnt/boot/efi   # the ESP, not disko's
```

## A6. Install

```bash
git clone https://github.com/TheodorRene/dotfiles.git /mnt/home/trc/dotfiles
nixos-install --flake /mnt/home/trc/dotfiles/nix#newhost      # sets the root password

# home-manager's out-of-store symlinks point at /home/trc/dotfiles — the clone
# must belong to the user before first login
chown -R 1000:1000 /mnt/home/trc
reboot
```

Then jump to [§First boot](#first-boot).

---

# Path B — by hand (how `disco` was done)

Use this for `hosts/disco`, or to install onto an existing layout. The
partitioning table above still applies; only the mechanics differ.

```bash
# /boot, unencrypted
mkfs.ext4 -L nixos-boot /dev/nvme0n1p7

# the container — DESTROYS whatever is in p8
cryptsetup luksFormat --type luks2 /dev/nvme0n1p8
cryptsetup open /dev/nvme0n1p8 dm_crypt-0

mkfs.btrfs -L nixos /dev/mapper/dm_crypt-0
mount /dev/mapper/dm_crypt-0 /mnt
for sv in root home nix var-log swap snapshots; do btrfs subvolume create /mnt/$sv; done
chattr +C /mnt/swap          # no COW: btrfs refuses a swapfile on a COW subvolume
umount /mnt

O=compress=zstd:1,noatime,ssd,space_cache=v2,discard=async
mount -o subvol=root,$O /dev/mapper/dm_crypt-0 /mnt
mkdir -p /mnt/{home,nix,var/log,swap,.snapshots,boot,mnt/btr_root}
mount -o subvol=home,$O      /dev/mapper/dm_crypt-0 /mnt/home
mount -o subvol=nix,$O       /dev/mapper/dm_crypt-0 /mnt/nix
mount -o subvol=var-log,$O   /dev/mapper/dm_crypt-0 /mnt/var/log
mount -o subvol=snapshots,$O /dev/mapper/dm_crypt-0 /mnt/.snapshots
mount -o subvol=swap,noatime /dev/mapper/dm_crypt-0 /mnt/swap
mount -o subvolid=5,noatime  /dev/mapper/dm_crypt-0 /mnt/mnt/btr_root
mount /dev/nvme0n1p7 /mnt/boot
mkdir -p /mnt/boot/efi && mount /dev/nvme0n1p1 /mnt/boot/efi
```

Then get the real UUIDs into `hosts/disco/disks-btrfs.nix`:

```bash
nixos-generate-config --root /mnt --show-hardware-config
blkid /dev/nvme0n1p8 /dev/mapper/dm_crypt-0
```

- `cryptRoot` ← the **btrfs filesystem** UUID (`/dev/mapper/dm_crypt-0`)
- `boot.initrd.luks.devices."dm_crypt-0".device` ← the **LUKS partition** UUID

Also copy the generated `boot.initrd.availableKernelModules` over the guessed
list. Then `nixos-install --flake …#disco` as in A6.

---

# First boot

```bash
passwd trc      # autologin doesn't remove the need for this: sudo and swaylock use it

# YubiKey → sudo (the PAM side is already declared in modules/security.nix)
mkdir -p ~/.config/Yubico
pamu2fcfg >> ~/.config/Yubico/u2f_keys      # tap when it blinks
pamu2fcfg >> ~/.config/Yubico/u2f_keys      # a BACKUP key — do it now
chmod 600 ~/.config/Yubico/u2f_keys
# verify without risking a lockout:
sudo -v         # then, in a second terminal: sudo -k && sudo echo works

# snapper's store for the /home config (the root config uses /.snapshots)
sudo btrfs subvolume create /home/.snapshots

# restore from backup — REINSTALL.md §3.6
#   ~/.ssh  ~/.gnupg  ~/.claude  ~/wallpapers  Firefox profile  impero-local.tar.gz
```

Optional TPM auto-unlock (`REINSTALL.md` §2.2 — a PIN is worth it):

```bash
systemd-analyze has-tpm2
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/<luks-partition>
# then uncomment crypttabExtraOpts in the host's disk file and rebuild
```

# Checklist

`REINSTALL.md` §3.7, plus what's new here:

- [ ] Waybar at the bottom, icons rendering (JetBrainsMono Nerd Font resolved)
- [ ] `$mod+Return` alacritty, `$mod+d` wofi, `$mod+o` firefox
- [ ] Audio keys, brightness keys (needs `video`/`input` groups — declared)
- [ ] `Print` / `Shift+Print` copy screenshots to the clipboard
- [ ] `swaymsg -t get_outputs` — do the names match `kanshi/config`? On a
      different machine the eDP/DP names can differ, and kanshi silently does
      nothing if they do
- [ ] `$mod+b` locks **and unlocks** — a rejected correct password means
      `security.pam.services.swaylock` didn't take effect
- [ ] `docker ps` without sudo
- [ ] `swapon --show`: zram prio 100, `/swap/swapfile` prio -1
- [ ] `systemctl show user.slice -p ManagedOOMMemoryPressure -p ManagedOOMMemoryPressureLimit`
      → `kill` / `60%`
- [ ] `cd ~/dev/impero` loads the devshell warm (nix-direnv)
- [ ] `getent hosts impero_db` resolves (declarative `/etc/hosts` block)
- [ ] `snapper -c home list` works as `trc` and shows a timeline snapshot
- [ ] `systemctl list-timers 'btrbk*' 'snapper*'` — armed
- [ ] the Windows entry appears in the GRUB menu (os-prober)
- [ ] `glxinfo -B` and `vainfo` — if either fails, try
      `local.intelForceProbe = "<id from lspci -nn>"`
