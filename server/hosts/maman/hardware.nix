# PROVISIONAL. Hand-written on 2026-11-07 from what Manjaro reported on the
# machine (lspci, lsmod), so that the flake evaluates before the install.
# INSTALL.md, Stage 4 overwrites this file with the output of
#   nixos-generate-config --no-filesystems --root /mnt
# and that generated version is the one to trust and commit.
#
# Hardware: HP Spectre x360 13-ac0XX (board 827E, BIOS F.20 of 2016-12-01),
# i7-7500U (Kaby Lake, 2C/4T), 8 GB soldered RAM, Samsung PM961 NVMe,
# Intel HD 620, Intel Wireless 8265, no wired NIC.
{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # nvme for the root disk; xhci/usb_storage/sd_mod so a USB disk or the
  # installer stick is usable from the initrd for rescue work.
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
