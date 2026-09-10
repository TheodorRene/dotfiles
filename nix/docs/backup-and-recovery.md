# Snapshots, backups, and getting back

Three layers, each covering what the one below it can't. Configured in
`modules/backup.nix`.

| Layer | Tool | Protects against | Survives |
|---|---|---|---|
| 1 | `snapper` (btrfs snapshots) | you deleted / broke something | nothing — same disk, same LUKS container |
| 2 | `btrbk` (btrfs send/receive → external LUKS drive) | the filesystem or the NVMe dying | the laptop dying |
| 3 | `restic` (encrypted, deduplicated, offsite) | theft, fire, and the drive on your desk | everything |

Layers 1 and 2 need a btrfs root — that is, a host whose disk module sets
`local.btrfsLayout = true` (`hosts/newhost/disks-disko.nix`,
`hosts/disco/disks-btrfs.nix`). On the ext4/LVM alternative they switch
themselves off and only layer 3 applies, so no timer is left failing against a
filesystem that can't snapshot.

## Layer 1 — snapper

Timelines: `/home` keeps 8 hourly / 14 daily / 8 weekly / 6 monthly; `/`
keeps 4 hourly / 7 daily / 2 weekly, plus a snapshot before every boot. `/nix`,
`/var/log` and `/swap` are deliberately *not* snapshotted — reproducible,
wanted-after-a-rollback, and forbidden by btrfs respectively.

```bash
snapper -c home list                       # no sudo: ALLOW_USERS = [ "trc" ]
snapper -c home create -d "before refactor"
snapper -c home status 42..43              # what changed between two snapshots
snapper -c home diff  42..43 /home/trc/some/file
snapper -c home undochange 42..0 /home/trc/dev/impero/backend/dev_data
```

`undochange N..0` restores from snapshot N to the live tree — the everyday
"put that file back" command. It takes paths, so it's safe to scope tightly.

One-time setup after install (snapper needs the subvolume to store `/home`
snapshots in): `sudo btrfs subvolume create /home/.snapshots`.

## Layer 2 — btrbk to an external drive

Hourly timer, incremental (only changed extents move), no-op when the drive
isn't mounted. The instance and target path are derived from the hostname
(`btrbk-<host>.service` → `/mnt/backup/<host>`), so one external drive can hold
several machines without collisions. Retention 30d / 12w / 12m / 1y.

Prepare the drive once — LUKS, because a plaintext copy of an encrypted laptop
is an odd thing to carry:

```bash
sudo cryptsetup luksFormat --type luks2 /dev/sdX1
sudo cryptsetup open /dev/sdX1 backup
sudo mkfs.btrfs -L backup /dev/mapper/backup
sudo systemctl start mnt-backup.mount       # the noauto/nofail mount from backup.nix
sudo systemctl start btrbk-$(hostname).service   # first run: full send, slow
```

Day to day: plug in, `cryptsetup open`, `systemctl start mnt-backup.mount`, and
let the next tick catch up. Check with `systemctl status btrbk-$(hostname)` and
`sudo btrbk list snapshots`.

**Restore a subvolume** (send in reverse — this is why the top-level subvolume is
mounted at `/mnt/btr_root`):

```bash
# read-only snapshot on the target -> a fresh subvolume on the laptop
sudo btrfs send /mnt/backup/$(hostname)/home.20260831T1200 \
  | sudo btrfs receive /mnt/btr_root/

# then swap it in (do this from a live ISO or a TTY with /home unused)
sudo mv /mnt/btr_root/home /mnt/btr_root/home.broken
sudo btrfs subvolume snapshot /mnt/btr_root/home.20260831T1200 /mnt/btr_root/home
sudo reboot
```

## Layer 3 — restic, offsite

**Off by default.** `modules/backup.nix` has `resticEnabled = false` so a fresh
build doesn't ship a daily timer that fails against a repository that doesn't
exist. To turn it on:

```bash
# 1. a password, root-only
printf '%s' 'a-long-passphrase-you-also-store-elsewhere' | sudo tee /etc/restic/password
sudo chmod 400 /etc/restic/password

# 2. if the repo needs credentials (B2/S3), an environment file
sudo tee /etc/restic/env <<'EOF'
B2_ACCOUNT_ID=...
B2_ACCOUNT_KEY=...
EOF
sudo chmod 400 /etc/restic/env
```

Then set `repository`, uncomment `environmentFile`, flip `resticEnabled = true`,
and rebuild. Better still, move both secrets into
[sops-nix](https://github.com/Mic92/sops-nix) or
[agenix](https://github.com/ryantm/agenix) so they're in git, encrypted, instead
of hand-placed files that a reinstall forgets.

Paths and excludes come straight from `REINSTALL.md` §1.3–1.4: all of
`/home/trc`, minus regenerable caches (`.cache .npm .nvm .cargo
.local/share/{bob,nvim}`) and `~/dev` build output. `~/dev` source itself is in
git remotes; the gitignored impero files (`.env`, `backend/dev_data` TLS keys,
`docker-compose.override.yml`) are **not** excluded, because they exist nowhere
else — that was the whole point of the `impero-local.tar.gz` step.

`backupPrepareCommand` takes a snapper snapshot before each run, so the copy is
consistent even while you're working. That's the automated form of
"**close Firefox first**" in `REINSTALL.md` §1.3: sqlite databases (Firefox
`places`/`cookies`, Claude Code state) are exactly the files that tear.

```bash
sudo restic -r <repo> --password-file /etc/restic/password snapshots
sudo restic -r <repo> --password-file /etc/restic/password restore latest \
  --target /tmp/restore --include /home/trc/.ssh
systemctl list-timers restic-backups-home    # is it actually running?
```

## Rolling back the *system*

Nothing to do with backups — this is the flake:

```bash
sudo nixos-rebuild switch --rollback              # previous generation, now
sudo nix-env --list-generations -p /nix/var/nix/profiles/system
```

…or pick an older generation in the GRUB menu. `boot.loader.grub.configurationLimit
= 12` keeps that list bounded, because `/boot` is only 2 GB and each generation
parks a kernel + initrd there.

## Integrity

`services.btrfs.autoScrub` reads and re-verifies every checksum on `/` monthly —
the only thing that finds bit rot before a snapshot chain comes to depend on the
bad extent.

```bash
sudo btrfs scrub status /
sudo btrfs device stats /        # nonzero error counters = start planning
sudo smartctl -a /dev/nvme0n1    # needs root (CLAUDE.md)
```

## If the machine won't boot

`docs/luks-boot-emergency-shell.md` still applies, with two changes: the
initramfs is systemd (NixOS), not dracut, and there's no LVM layer. The first
diagnostic is unchanged and still unrecoverable after the fact:

```bash
ls /dev/mapper/      # dm_crypt-0 present -> unlock worked, fs/mount is at fault
                     # absent           -> the LUKS unlock never completed
```

With btrfs, a root filesystem that mounts but boots into something broken is
recoverable without a reinstall: boot the previous GRUB generation, or from a
live ISO mount `subvolid=5` and swap `root` for a `.snapshots/N/snapshot`.
