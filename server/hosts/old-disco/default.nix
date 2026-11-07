# old-disco: HP Spectre x360 13-ac0XX (late 2016) as an always-on home server.
# Phase 1 of ../../README.md only: boots, stays up, reachable over Tailscale.
# No apps, no containers.
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware.nix ./disks.nix ];

  networking.hostName = "old-disco";
  # The release you install from. Set once, never bump. It isn't a version
  # number; it records which defaults this machine's state was created under.
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep plenty of generations: on a headless box the boot menu IS the recovery
  # plan. 20 kernels+initrds fit easily in the 1 GB ESP.
  boot.loader.systemd-boot.configurationLimit = 20;

  # Blank the console after 60 s so the panel isn't lit 24/7 with the lid open.
  # (Manjaro had `pcie_aspm=off` here; it's not carried over: the firmware's
  # FADT already disables ASPM, and the kernel logs that it does.)
  boot.kernelParams = [ "consoleblank=60" ];

  # --- A server does not sleep -----------------------------------------------
  # Both halves matter: logind stops the lid from triggering suspend, and
  # disabling the targets means nothing else can reach it either.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # --- Hardware --------------------------------------------------------------
  # Firmware for the Intel 8265 wifi (and CPU microcode via hardware.nix).
  # Without it there is no network at all on this machine.
  hardware.enableRedistributableFirmware = true;
  # Thin chassis, 15 W CPU, lid open in a corner: let thermald manage it before
  # the firmware's hard throttle does.
  services.thermald.enable = true;

  # --- Network ---------------------------------------------------------------
  # NetworkManager rather than plain DHCP because the machine has no wired NIC:
  # it must work on wifi from day one, and pick up a USB ethernet adapter when
  # one is plugged in. The wifi password goes in with `nmcli` on first boot
  # (stored in /etc/NetworkManager/system-connections/, not in git).
  networking.networkmanager.enable = true;
  # Power save on the wifi adds latency and drops on a box that's mostly idle.
  networking.networkmanager.wifi.powersave = false;

  networking.firewall = {
    enable = true;
    # The entire security model: services bind normally, and only the tailnet
    # can reach them. Nothing is open to the LAN or the WAN.
    trustedInterfaces = [ "tailscale0" ];
  };

  services.tailscale = {
    enable = true;
    # "client" also sets the loose reverse-path check Tailscale needs. Widen to
    # "server" if this ever becomes an exit node or subnet router.
    useRoutingFeatures = "client";
  };

  services.openssh = {
    enable = true;
    openFirewall = false; # reachable over tailscale0 only
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.trc = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    # Public keys of the machines you'll connect FROM. Get it wrong and the
    # physical keyboard is the way back in, which is fine; it's in the flat.
    openssh.authorizedKeys.keys = [
      # the XPS (disco), ~/.ssh/id_ed25519.pub
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGOCwoAxsag6FY6CzBxZr6uGcQEBsx1pfS7oYCwsEUBb"
    ];
  };

  # --- Locale ----------------------------------------------------------------
  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";
  # The Spectre's keyboard is Norwegian (Manjaro had KEYMAP=no). This matters
  # most for passwords typed at the physical console.
  console.keyMap = "no";

  # --- Housekeeping ----------------------------------------------------------
  # 8 GB of soldered RAM; zram at half of it.
  zramSwap = { enable = true; memoryPercent = 50; };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';

  environment.systemPackages = with pkgs; [ git vim htop tmux ];
}
