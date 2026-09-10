# Machine-specific hardware for newhost.
#
# Replace the initrd module list with what the installer detects:
#   nixos-generate-config --root /mnt --show-hardware-config
# and copy its boot.initrd.availableKernelModules line over the one below. The
# defaults here cover NVMe/SATA/USB booting on a modern Intel laptop, which is
# usually enough to get the LUKS prompt up — but "usually" is a bad thing to
# discover at 2am with no root filesystem.
{ config, lib, pkgs, ... }:

{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Uncomment for a virtual camera (v4l2loopback-dkms on Ubuntu), as used with
  # Kooha/OBS-style capture:
  # boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  # boot.kernelModules = [ "v4l2loopback" ];

  # If this machine has a fingerprint reader you want for login/sudo:
  # services.fprintd.enable = true;
  # security.pam.services.sudo.fprintAuth = true;   # note: YubiKey u2f is
  #   already `sufficient` in modules/security.nix, so both can coexist.
}
