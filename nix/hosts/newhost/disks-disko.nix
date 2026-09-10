# Disk layout for newhost, declared with disko: LUKS2 → btrfs subvolumes.
#
# ---------------------------------------------------------------------------
# WHAT DISKO WILL AND WON'T TOUCH
#
# disko normally owns a whole disk and wipes it. That is exactly wrong on a
# dual-boot machine, so this layout is scoped to **two existing partitions**:
# each `disk` entry below points at a *partition*, not at /dev/nvme0n1, and
# declares no partition table. disko therefore never runs sgdisk, and cannot
# see — let alone reformat — the Windows partitions or the shared ESP.
#
# Which means you create those two partitions yourself, once, before running
# disko (shrink Windows from inside Windows' own Disk Management first — it is
# the only thing that reliably moves NTFS metadata):
#
#   ~2 GB   -> /boot   unencrypted ext4. LUKS2's argon2id KDF is not something
#                      GRUB can unlock, so kernel + initrd must live outside the
#                      container. 2 GB because each NixOS generation parks a
#                      kernel + initrd here (~120 MB); see modules/boot.nix's
#                      configurationLimit.
#   the rest -> LUKS   the container everything else lives in.
#
# The ESP is *not* declared here — it already exists and holds the Windows boot
# loader; it's a plain fileSystems entry at the bottom of this file, and GRUB
# installs into it alongside Windows.
#
# THREE PLACEHOLDERS below. Fill them from `lsblk -f` / `blkid` on the target
# machine. Prefer /dev/disk/by-id/... over /dev/nvme0n1pN: stable across kernel
# reorderings, and it makes it much harder to point this at the wrong disk.
# ---------------------------------------------------------------------------
{ disko, lib, ... }:

let
  # e.g. "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_1234567890-part7"
  bootPartition = "/dev/disk/by-id/REPLACE-ME-part-boot";
  luksPartition = "/dev/disk/by-id/REPLACE-ME-part-luks";
  # The existing ESP, by filesystem UUID (`blkid /dev/nvme0n1p1`) — a short
  # 8-hex-digit vfat UUID like "3491-D302".
  espUuid = "REPLACE-ME-ESP-UUID";

  # zstd:1 is cheap enough to be free on a modern CPU, and source trees /
  # node_modules / cargo target dirs compress 2–3x. noatime matters more on
  # btrfs than elsewhere: an atime update is a COW write.
  baseOpts = [ "compress=zstd:1" "noatime" "ssd" "space_cache=v2" "discard=async" ];
in
{
  imports = [ disko.nixosModules.disko ];

  # Turns on the snapper/btrbk layers in ../../modules/backup.nix.
  local.btrfsLayout = true;

  disko.devices.disk = {
    # --- /boot: unencrypted, outside the container --------------------------
    boot = {
      type = "disk";
      device = bootPartition;
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/boot";
      };
    };

    # --- the LUKS container and everything in it ----------------------------
    cryptroot = {
      type = "disk";
      device = luksPartition;
      content = {
        type = "luks";
        name = "dm_crypt-0"; # keeps `ls /dev/mapper/` reading the same as on disco
        settings = {
          allowDiscards = true; # so fstrim.timer can reach the SSD through LUKS
          bypassWorkqueues = true; # measurably faster on NVMe, safe single-user
        };
        # Install-time only: disko reads this to luksFormat the partition.
        #   (umask 077; head -c 64 /dev/urandom | base64 > /tmp/luks.key)
        # …or use a passphrase you'll actually remember, since that's what you
        # type at every boot:
        #   printf '%s' 'the passphrase' > /tmp/luks.key
        # Swap `passwordFile` for `askPassword = true;` to be prompted instead.
        passwordFile = "/tmp/luks.key";
        # After enrolling the TPM (docs/install.md §6), unlock without typing:
        # settings.crypttabExtraOpts = [ "tpm2-device=auto" ];

        content = {
          type = "btrfs";
          extraArgs = [ "-L" "nixos" "-f" ];

          # Flat subvolumes — the layout snapper and btrbk expect.
          subvolumes = {
            "root" = { mountpoint = "/"; mountOptions = baseOpts; };
            "home" = { mountpoint = "/home"; mountOptions = baseOpts; };

            # NOT snapshotted: fully reproducible from the flake, and
            # snapshotting it would pin every dead GC root.
            "nix" = { mountpoint = "/nix"; mountOptions = baseOpts; };

            # NOT snapshotted: a rollback shouldn't erase the logs that explain
            # why you rolled back.
            "var-log" = { mountpoint = "/var/log"; mountOptions = baseOpts; };

            # snapper's store for the `root` config.
            "snapshots" = { mountpoint = "/.snapshots"; mountOptions = baseOpts; };

            # No compression, no COW: btrfs refuses to activate a swapfile on a
            # compressed or snapshotted subvolume. NixOS creates the file itself
            # with `btrfs filesystem mkswapfile`, which sets nodatacow for us.
            "swap" = { mountpoint = "/swap"; mountOptions = [ "noatime" ]; };
          };
        };
      };
    };
  };

  # --- The existing ESP, shared with Windows --------------------------------
  # Deliberately outside disko: it already exists, and nothing here should be
  # able to format it. GRUB installs into it next to the Windows loader.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/${espUuid}";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # --- The top-level subvolume (id 5) ---------------------------------------
  # btrbk needs to see the subvolume tree from above to send/receive it, and it's
  # the mount you rename subvolumes from when rolling a snapshot back by hand.
  # Not a subvolume itself, so disko can't express it.
  fileSystems."/mnt/btr_root" = {
    device = "/dev/mapper/dm_crypt-0";
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" ];
  };

  # --- Swap ------------------------------------------------------------------
  # 8 GB overflow at priority -1, strictly a backstop behind zram (priority 100,
  # see ../../modules/memory.nix).
  swapDevices = [{
    device = "/swap/swapfile";
    size = 8192; # MiB
    priority = -1;
  }];
}
