# Snapshots + backups. Three layers, because they protect against different
# things and only the third one survives losing the laptop:
#
#   1. snapper  — btrfs timeline snapshots on the same disk. Instant, ~free
#                 (COW), and the answer to "I just deleted / broke something".
#                 NOT a backup: same disk, same LUKS container.
#   2. btrbk    — btrfs send/receive of those snapshots to an external drive.
#                 Incremental (only changed extents cross the cable), so a
#                 daily run is seconds after the first one.
#   3. restic   — encrypted, deduplicated, versioned copies of the
#                 irreplaceable paths, to somewhere that isn't this desk.
#
# The whole point of REINSTALL.md Part 1 was doing layer 3 by hand, once, under
# time pressure. This makes it a timer.
{ config, lib, pkgs, ... }:

let
  # Flip to true once you've created the repo + password file (see
  # ../docs/backup-and-recovery.md). Left off so a fresh build doesn't ship a
  # timer that fails every hour against a repository that doesn't exist yet.
  resticEnabled = false;

  # Where btrbk expects the external drive to be mounted. LUKS-formatted, so the
  # backup is encrypted at rest too — a plaintext copy of a LUKS-encrypted
  # laptop is a strange thing to carry around.
  backupMount = "/mnt/backup";

  # Layers 1 and 2 are btrfs features. The flag is set by the disk-layout module
  # (hosts/disco/disks-btrfs.nix), so swapping in disks-ext4-lvm.nix drops
  # snapper/btrbk/scrub instead of leaving behind timers that fail every tick.
  #
  # It can't be derived from `config.fileSystems."/".fsType`: this module also
  # *defines* a fileSystems entry (the external backup drive), so reading that
  # option to decide its own definitions is an infinite recursion.
  btrfs = config.local.btrfsLayout;

  # One external drive can hold several machines' backups without collision.
  host = config.networking.hostName;
in
{
  config = lib.mkMerge [
    (lib.mkIf btrfs {
      # --- 0. Integrity ----------------------------------------------------------
      # btrfs checksums everything it reads, but only a scrub reads *everything*.
      # Monthly: catches bit rot and a dying NVMe before a snapshot chain depends on
      # the bad extent.
      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = [ "/" ];
      };

      # --- 1. snapper ------------------------------------------------------------
      # /home gets the generous retention (this is where irreplaceable work lives:
      # ~/dotfiles, ~/dev's gitignored files, ~/.claude state). / gets a shorter
      # timeline — with a flake, the system is rebuildable from git, so root
      # snapshots exist to undo a bad `nixos-rebuild` fast, not to archive.
      #
      # NOT snapshotted: /nix (reproducible, and snapshots would pin dead GC roots),
      # /var/log (a rollback shouldn't erase the evidence), /swap (btrfs forbids it).
      services.snapper.configs = {
        home = {
          SUBVOLUME = "/home";
          FSTYPE = "btrfs";
          ALLOW_USERS = [ "trc" ]; # so `snapper -c home list` needs no sudo
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = 8;
          TIMELINE_LIMIT_DAILY = 14;
          TIMELINE_LIMIT_WEEKLY = 8;
          TIMELINE_LIMIT_MONTHLY = 6;
          TIMELINE_LIMIT_YEARLY = 0;
        };

        root = {
          SUBVOLUME = "/";
          FSTYPE = "btrfs";
          ALLOW_USERS = [ "trc" ];
          TIMELINE_CREATE = true;
          TIMELINE_CLEANUP = true;
          TIMELINE_LIMIT_HOURLY = 4;
          TIMELINE_LIMIT_DAILY = 7;
          TIMELINE_LIMIT_WEEKLY = 2;
          TIMELINE_LIMIT_MONTHLY = 0;
          TIMELINE_LIMIT_YEARLY = 0;
        };
      };

      # Snapshot / before each boot, so "it broke after the last rebuild" has a
      # before-image even if the timeline snapshot happened to be stale.
      services.snapper.snapshotRootOnBoot = true;

      # --- 2. btrbk to the external drive ---------------------------------------
      # Runs hourly *if the drive is there* and does nothing (exit 0, logged) if it
      # isn't — that's what `stream_buffer`-less, plain local targets do when the
      # path is absent. Plug the drive in, and the next tick catches up.
      #
      # Restore is `btrfs send` in reverse — see ../docs/backup-and-recovery.md.
      services.btrbk.instances.${host} = {
        onCalendar = "hourly";
        settings = {
          timestamp_format = "long";
          snapshot_preserve_min = "2d";
          snapshot_preserve = "14d 8w 6m";
          target_preserve_min = "no";
          target_preserve = "30d 12w 12m 1y";
          # btrbk makes its own snapshots (independent of snapper's) so retention on
          # the target isn't hostage to snapper's cleanup.
          snapshot_dir = ".btrbk-snapshots";

          volume."/mnt/btr_root" = {
            subvolume = {
              "home" = { };
              "root" = { };
            };
            target = "${backupMount}/${host}";
          };
        };
      };

      # The external drive: LUKS, opened by hand when you plug it in. `noauto` so a
      # missing drive never blocks boot, and nofail so a stale entry can't strand
      # the machine in emergency mode.
      #
      #   sudo cryptsetup luksFormat /dev/sdX1 && sudo cryptsetup open /dev/sdX1 backup
      #   sudo mkfs.btrfs -L backup /dev/mapper/backup
      #   sudo systemctl start mnt-backup.mount
      fileSystems.${backupMount} = {
        device = "/dev/mapper/backup";
        fsType = "btrfs";
        options = [ "noatime" "compress=zstd:1" "noauto" "nofail" ];
      };

      environment.systemPackages = with pkgs; [
        btrfs-progs
        snapper
      ];
    })

    {
      environment.systemPackages = [ pkgs.restic ];

      # --- 3. restic, offsite ----------------------------------------------------
      # Paths and excludes are lifted straight from REINSTALL.md §1.3–1.4: back up
      # everything in ~ that isn't regenerable, skip ~/dev (pushed to remotes, and
      # ~90% of the disk) apart from the gitignored impero bits that exist nowhere
      # else.
      services.restic.backups = lib.mkIf resticEnabled {
        home = {
          initialize = true;

          # Point this at wherever you actually keep it. Examples:
          #   "b2:bucket-name:disco"                  (Backblaze B2)
          #   "sftp:user@host:/srv/restic/disco"       (a box you own)
          #   "/mnt/backup/restic"                     (same drive as btrbk — fine,
          #                                             different failure mode)
          repository = "REPLACE-ME";

          # Two secrets, neither of which belongs in this git repo. Create them with
          # mode 0400 root-owned, or wire up sops-nix/agenix:
          #   printf '%s' 'the-restic-passphrase' | sudo tee /etc/restic/password
          #   sudo chmod 400 /etc/restic/password
          passwordFile = "/etc/restic/password";
          # environmentFile = "/etc/restic/env";   # B2_ACCOUNT_ID=... etc.

          paths = [
            "/home/trc"
          ];

          exclude = [
            # regenerable caches
            "/home/trc/.cache"
            "/home/trc/.npm"
            "/home/trc/.nvm"
            "/home/trc/.cargo"
            "/home/trc/.local/share/bob"
            "/home/trc/.local/share/nvim"
            "/home/trc/.local/share/Trash"
            # build artefacts and clonable trees
            "/home/trc/dev/**/node_modules"
            "/home/trc/dev/**/target"
            "/home/trc/dev/**/.git"
            "/home/trc/dev/**/dist"
            "/home/trc/dev/**/obj"
            "/home/trc/dev/**/bin"
            # snapshots of this very filesystem
            "/home/trc/.snapshots"
          ];

          # Snapshot /home first and back *that* up, so the copy is consistent even
          # while you're working (restic on a live tree can catch half-written files;
          # sqlite DBs — Firefox places/cookies, Claude Code state — are exactly the
          # files that hurt when torn). This is the automated form of the "close
          # Firefox first" warning in REINSTALL.md §1.3.
          backupPrepareCommand = lib.mkIf btrfs ''
            ${pkgs.snapper}/bin/snapper -c home create --description restic-pre --cleanup-algorithm number
          '';

          pruneOpts = [
            "--keep-daily 14"
            "--keep-weekly 8"
            "--keep-monthly 12"
            "--keep-yearly 3"
          ];

          timerConfig = {
            OnCalendar = "daily";
            # Laptop: don't skip the run just because it was asleep at 03:00.
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    }
  ];
}
