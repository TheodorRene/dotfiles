# Small system services.
{ config, lib, pkgs, ... }:

{
  # `locate` is aliased to plocate in zsh/alias.zsh. plocate is the only
  # implementation nixpkgs still supports (findutils' locate was dropped, along
  # with the `localuser` option), so there is nothing to choose here.
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
  };

  # TRIM the SSD weekly. Works because the LUKS device allows discards
  # (hosts/disco/hardware.nix); verify with `lsblk --discard`.
  services.fstrim.enable = true;

  # (Intel thermal management lives in ./hardware-intel.nix — it's CPU-specific.)

  # Battery/AC state for waybar's battery module and swayidle's on-AC logic.
  services.upower.enable = true;

  # Printing was a snap on Ubuntu; declare it properly (mDNS discovery for
  # network printers included).
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Timesync — chrony handles suspend/resume jumps better than systemd-timesyncd
  # on a laptop that's closed for days.
  services.chrony.enable = true;
  services.timesyncd.enable = false;

  # journald: keep boots bounded. Relevant to docs/luks-boot-emergency-shell.md —
  # a *failed* boot still leaves nothing (that /run is tmpfs is a kernel fact,
  # not a journald setting), but persistent storage means a successful boot after
  # a hang keeps the previous boots for comparison.
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=2G
    MaxRetentionSec=1month
  '';
}
