# Host: newhost — the new machine. Intel CPU + iGPU, dual-boot off a shared ESP,
# LUKS + btrfs partitioned declaratively with disko.
#
# ---------------------------------------------------------------------------
# RENAME ME. Pick the real hostname and change it in three places:
#
#   git mv hosts/newhost hosts/<name>
#   sed -i 's/newhost/<name>/' flake.nix hosts/<name>/default.nix
#
# (flake.nix's `nixosConfigurations.newhost`, this file's networking.hostName,
# and the directory name. Nothing else refers to it — btrbk derives its instance
# and target path from networking.hostName.)
# ---------------------------------------------------------------------------
{ nixos-hardware, ... }:

{
  imports = [
    ../../modules/common.nix
    ../../modules/hardware-intel.nix
    ./hardware.nix
    ./disks-disko.nix

    nixos-hardware.nixosModules.common-cpu-intel
    # Drop these two if it's a desktop — they pull in laptop power management,
    # and common-pc-laptop-ssd enables fstrim + relatime tuning.
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "newhost";

  # Set to about half of this machine's RAM. 16 suits 30–32 GB; use 8 on a 16 GB
  # machine, 24–32 on 64 GB.
  local.zramMaxGiB = 16;

  # Only needed if mesa doesn't recognise the GPU yet — check with
  # `nix-shell -p mesa-demos --run 'glxinfo -B'` and `lspci -nn | grep -i vga`.
  # Leave null unless graphics actually fail.
  local.intelForceProbe = null;

  # The NixOS release you install from. Set it once; never bump it.
  system.stateVersion = "26.05";
}
