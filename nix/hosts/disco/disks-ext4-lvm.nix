# ALTERNATIVE disk layout: the *existing* Ubuntu one — LUKS → LVM → ext4.
#
# Use this instead of ./disks-btrfs.nix if you want to install NixOS in place
# without repartitioning: `mkfs.ext4` the existing ubuntu-vg/ubuntu-lv and keep
# everything else. Swap it in hosts/disco/default.nix.
#
# The UUIDs are real, read off this machine on 2026-08-31 (`lsblk -f`). Only the
# root filesystem UUID changes when you reformat the LV; the LUKS container and
# /boot keep theirs.
#
# Tradeoff vs. btrfs: no snapshots, so no `snapper` rollback and no `btrbk`
# send/receive — ../../modules/backup.nix degrades to restic only.
{ config, lib, pkgs, ... }:

{
  # ../../modules/backup.nix keys its snapper/btrbk layers off this; leaving it
  # false means an ext4 install gets restic only, with no timers that would fail
  # against a filesystem that can't snapshot.
  local.btrfsLayout = false;

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];

  boot.initrd.luks.devices."dm_crypt-0" = {
    device = "/dev/disk/by-uuid/a68cb466-3822-421d-a6f5-64e9d5b4976c";
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  # LVM inside the container activates automatically once the LUKS device
  # appears — the dracut `rd.lvm.lv`-in-the-image trap from
  # docs/luks-boot-emergency-shell.md has no NixOS equivalent.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/c59e2222-b738-48df-8e62-d15ce0cbf0ff";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/e7e8ff84-04a1-45f2-ad14-7718f334b3e6";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/3491-D302";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # 8 GB overflow behind zram; replaces the manual fallocate/mkswap in
  # REINSTALL.md §3.3.
  swapDevices = [{
    device = "/swap.img";
    size = 8192;
    priority = -1;
  }];
}
