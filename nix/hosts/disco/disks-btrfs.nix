# Disk layout: LUKS2 → btrfs with flat subvolumes. Encrypted at rest, snapshotable,
# and send/receive-able to an external drive (see ../../modules/backup.nix).
#
# ---------------------------------------------------------------------------
# Partition table (unchanged from the Ubuntu install except for p8's contents):
#
#   nvme0n1p1  vfat  384M  ESP         -> /boot/efi   shared with Windows, never format
#   nvme0n1p2         128M  MSR                       Windows, untouched
#   nvme0n1p3  ntfs  473G  OS                         Windows C:, untouched
#   nvme0n1p4-6 ntfs        WINRETOOLS/Image/DELLSUPPORT  Dell recovery, untouched
#   nvme0n1p7  ext4    2G              -> /boot       unencrypted: GRUB can't open
#                                                     a LUKS2/argon2id container
#   nvme0n1p8  LUKS  451G  -> dm_crypt-0 -> btrfs     everything else
#
# btrfs subvolumes (flat, all top-level — the layout snapper and btrbk expect):
#
#   root        -> /            snapshotted
#   home        -> /home        snapshotted
#   nix         -> /nix         NOT snapshotted: fully reproducible from the flake,
#                               and snapshotting it would pin every GC root
#   var-log     -> /var/log     NOT snapshotted: a rollback shouldn't erase the
#                               logs that explain why you rolled back
#   swap        -> /swap        NOT snapshotted, nodatacow (btrfs refuses a
#                               swapfile on a COW/snapshotted subvolume)
#   snapshots   -> /.snapshots  snapper's store for the `root` config
#
# LVM is gone: it only existed to give ext4 a resizable volume, and btrfs
# subvolumes do that job without the extra device-mapper layer (one less thing
# that can fail to activate — cf. docs/luks-boot-emergency-shell.md).
#
# !!! UUIDs !!! The LUKS UUID below is the *current* container's. If you
# `cryptsetup luksFormat` p8 again (you will, to put btrfs in it), the container
# and filesystem UUIDs change. The reliable move: partition + mkfs per
# ../../docs/install.md, then let `nixos-generate-config --root /mnt` print the
# real UUIDs and paste them here before the first build.
# ---------------------------------------------------------------------------
{ config, lib, pkgs, ... }:

let
  # Same fs for every subvolume, so define the device once.
  cryptRoot = "/dev/disk/by-uuid/REPLACE-WITH-BTRFS-FS-UUID";

  # zstd:1 — cheap enough to be free on a 16-core CPU, and source trees /
  # node_modules / cargo target dirs compress 2–3x. noatime matters a lot on
  # btrfs (atime updates are COW writes).
  baseOpts = [ "compress=zstd:1" "noatime" "ssd" "space_cache=v2" "discard=async" ];

  subvol = name: extra: {
    device = cryptRoot;
    fsType = "btrfs";
    options = [ "subvol=${name}" ] ++ baseOpts ++ extra;
  };
in
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];

  # btrfs tooling in the initrd (multi-device scan, and `btrfs` for rescue work).
  boot.supportedFilesystems.btrfs = true;

  # --- LUKS ------------------------------------------------------------------
  boot.initrd.luks.devices."dm_crypt-0" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-LUKS-PARTITION-UUID";
    # Keeps the mapper name from the Ubuntu install, so the first diagnostic in
    # docs/luks-boot-emergency-shell.md (`ls /dev/mapper/`) still reads the same.
    allowDiscards = true;
    # bypassWorkqueues speeds up NVMe + LUKS noticeably (fewer context switches
    # per I/O); safe on a single-user laptop.
    bypassWorkqueues = true;
    # After enrolling the TPM (see ../../docs/install.md), uncomment to unlock
    # without typing the passphrase:
    # crypttabExtraOpts = [ "tpm2-device=auto" ];
  };

  # Turns on the snapper/btrbk layers in ../../modules/backup.nix. Declared
  # there, set here, because it is a property of the disk layout.
  local.btrfsLayout = true;

  # --- Subvolumes ------------------------------------------------------------
  fileSystems."/" = subvol "root" [ ];
  fileSystems."/home" = subvol "home" [ ];
  fileSystems."/var/log" = subvol "var-log" [ ];
  fileSystems."/.snapshots" = subvol "snapshots" [ ];

  # The Nix store: compressible, but never snapshot it. `nodatacow` is wrong
  # here (it would disable compression too) — just leave it out of the snapshot
  # configs in ../../modules/backup.nix.
  fileSystems."/nix" = subvol "nix" [ ];

  # Swap subvolume: no compression, no COW. btrfs will refuse to activate a
  # swapfile that lives on a compressed or snapshotted subvolume.
  fileSystems."/swap" = {
    device = cryptRoot;
    fsType = "btrfs";
    options = [ "subvol=swap" "noatime" ];
  };

  # The top-level subvolume (id 5). btrbk needs to see the subvolume tree from
  # above to send/receive it, and it's the mount you rename subvolumes from when
  # rolling back a snapshot by hand.
  fileSystems."/mnt/btr_root" = {
    device = cryptRoot;
    fsType = "btrfs";
    options = [ "subvolid=5" "noatime" ];
  };

  # --- Boot partitions -------------------------------------------------------
  # Unencrypted /boot: LUKS2's argon2id KDF is not something GRUB can unlock, so
  # kernel + initrd must sit outside the container. Only kernels live here.
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/e7e8ff84-04a1-45f2-ad14-7718f334b3e6";
    fsType = "ext4";
  };

  # Windows' ESP — GRUB installs *into* it next to the Windows loader. Never
  # format this partition.
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/3491-D302";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # --- Swap ------------------------------------------------------------------
  # 8 GB overflow behind zram (priority 100 — see ../../modules/memory.nix).
  # NixOS creates this with `btrfs filesystem mkswapfile` when it's on btrfs, so
  # the nodatacow/no-compression requirements are handled for us.
  swapDevices = [{
    device = "/swap/swapfile";
    size = 8192; # MiB
    priority = -1;
  }];
}
