# Sway/Wayland desktop.
#
# Note what is *not* here: sway/config, waybar/, wofi/, mako/, swaylock/,
# kanshi/ stay hand-written in this repo and are symlinked into ~/.config by
# home/dotfiles.nix. This module only installs the binaries those configs call
# and wires up the session-level plumbing that needs root.
{ config, lib, pkgs, ... }:

{
  programs.sway = {
    enable = true;
    # Wrap sway so GTK apps launched from it find their schemas/themes.
    wrapperFeatures.gtk = true;

    extraPackages = with pkgs; [
      # session bits sway/config execs directly
      swaybg
      swaylock
      swayidle
      waybar
      wofi
      kanshi
      mako
      # screenshots: Print / Shift+Print bindings
      grim
      slurp
      wl-clipboard
      # display debugging + the toggle-display.sh / set-display-ratio.sh helpers
      wdisplays
      wlr-randr
      wl-mirror
      wev
      # media keys
      playerctl
      brightnessctl
      pavucontrol
      # $mod+Shift+e uses swaynag; it ships with sway itself
    ];

    # sway/config already re-imports the environment into systemd/D-Bus itself
    # (`systemctl --user import-environment` + dbus-update-activation-environment),
    # so nothing extra needed here.
  };

  # --- Login ----------------------------------------------------------------
  # GDM with autologin, matching etc/gdm3/custom.conf +
  # scripts/install-gdm-autologin.sh. Wayland session, defaulting to sway so
  # autologin lands in the tiling WM and not a GNOME session.
  services.displayManager = {
    # GDM is Wayland-only in current nixpkgs (the `wayland` option was
    # removed), which is what we want anyway.
    gdm.enable = true;
    autoLogin = {
      enable = true;
      user = "trc";
    };
    defaultSession = "sway";
  };

  # Lighter alternative if GDM's GNOME dependencies start to grate — greetd
  # autologin straight into sway, no display manager UI at all:
  #
  # services.greetd = {
  #   enable = true;
  #   settings.default_session = {
  #     command = "${pkgs.sway}/bin/sway";
  #     user = "trc";
  #   };
  # };

  # --- Screen lock -----------------------------------------------------------
  # swaylock authenticates through PAM, and on NixOS it has *no* PAM stack
  # unless declared. Without this, $mod+b locks the screen and then rejects the
  # correct password — the classic NixOS swaylock lockout.
  security.pam.services.swaylock = { };

  # --- Portals ---------------------------------------------------------------
  # Declarative twin of xdg-desktop-portal/sway-portals.conf. Screen sharing
  # (Slack/Firefox/Kooha) goes through the wlr backend; everything else via GTK.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "wlr" ];
    };
  };

  # GTK_USE_PORTAL=0 is exported by zsh/exports.zsh and sway/config; portals
  # stay available for screen capture without GTK file dialogs routing through
  # them.

  # --- Backlight -------------------------------------------------------------
  # brightnessctl ships a udev rule that makes the backlight node writable by
  # the `video` group (keyboard LEDs by `input`). On Ubuntu the groups had to be
  # added by hand (REINSTALL.md §3.5) — here modules/users.nix declares them, so
  # the XF86MonBrightness bindings work on first boot.
  services.udev.packages = [ pkgs.brightnessctl ];

  # waybar's power-profiles-daemon module, and the "performance" profile the
  # dev workload wants.
  services.power-profiles-daemon.enable = true;

  # Firefox, natively (no snap, no Mozilla apt repo, no pinning — the whole of
  # scripts/install-firefox-apt.sh collapses to this). Wayland is the default
  # for the nixpkgs build; MOZ_ENABLE_WAYLAND in zsh/exports.zsh is harmless.
  programs.firefox.enable = true;

  # Electron apps (Slack, VS Code) read this from the session environment;
  # sway/config also sets it via dbus-update-activation-environment.
  environment.sessionVariables.ELECTRON_OZONE_PLATFORM_HINT = "wayland";

  # GTK apps under a bare Sway session have no settings daemon; dconf gives
  # them somewhere to read theme/font settings from.
  programs.dconf.enable = true;
}
