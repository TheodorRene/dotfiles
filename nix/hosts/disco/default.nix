# Host: disco — Dell XPS 14 (DA14260), Intel Core Ultra X7 358H (Panther Lake),
# 30 GB RAM, 1920x1200@120 eDP, LUKS root, dual-boot with Windows.
#
# Installed by hand, so its disks are described with literal UUIDs rather than
# disko. See ../newhost for the declarative-partitioning version.
{ nixos-hardware, ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/hardware-intel.nix
    ./hardware.nix

    # Disk layout. btrfs (subvolumes + snapshots + send/receive) is the default;
    # swap in ./disks-ext4-lvm.nix instead to install onto the existing Ubuntu
    # LUKS→LVM→ext4 layout without repartitioning.
    ./disks-btrfs.nix
    # ./disks-ext4-lvm.nix

    nixos-hardware.nixosModules.common-cpu-intel
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "disco";

  # 30 GB of RAM — cap zram at ~half.
  local.zramMaxGiB = 16;

  # Panther Lake's display device id; mesa won't drive it without this yet.
  local.intelForceProbe = "b080";

  # The NixOS release this host was first installed from. Do NOT bump it on
  # upgrades — it only exists to keep stateful defaults (databases, etc.) stable.
  system.stateVersion = "26.05";
}
