# Boot loader + initrd.
{ config, lib, pkgs, ... }:

{
  # GRUB, not systemd-boot: the ESP is a 384 MB partition shared with Windows,
  # and this machine keeps its kernels on a separate unencrypted ext4 /boot.
  # systemd-boot can only load kernels from the ESP itself — too small, and it
  # would mean writing NixOS generations into Windows' ESP.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # EFI install, no MBR target
    efiInstallAsRemovable = false;
    # Detect the Windows boot loader in the shared ESP and add a menu entry.
    useOSProber = true;
    # /boot is 2 GB and every NixOS generation parks a kernel + initrd there
    # (~120 MB a pop). Unbounded generations fill it and then rebuilds fail.
    configurationLimit = 12;
  };

  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot/efi";
  };

  # systemd in the initrd — the same shape as Ubuntu's dracut-systemd here, and
  # the prerequisite for TPM2 unlock (hosts/disco/hardware.nix) and for readable
  # `journalctl -b` output covering the unlock stage.
  #
  # Boot-hang lore (docs/luks-boot-emergency-shell.md): the ~90 s hang matched
  # systemd's DefaultDeviceTimeoutSec, i.e. the LV device job timed out — not the
  # passphrase prompt. If that recurs here, raise it in the initrd rather than
  # chasing the cryptsetup step:
  #   boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "180";
  boot.initrd.systemd.enable = true;

  # Panther Lake needs recent graphics/PMU code; the stable kernel lags.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    # Quiet-ish boot; drop these while debugging an initrd hang.
    "quiet"
    "loglevel=4"
  ];

  # Ubuntu's setup relied on NetworkManager-wait-online being disabled to stop
  # it blocking boot ~5 s (scripts/install-perf-tuning.sh). NixOS ships it
  # enabled too — see modules/networking.nix.
}
