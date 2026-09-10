# home-manager config for trc.
{ config, lib, pkgs, ... }:

{
  imports = [
    ./dotfiles.nix
    ./packages.nix
  ];

  home.username = "trc";
  home.homeDirectory = "/home/trc";

  # Same rule as system.stateVersion: set once, don't bump.
  home.stateVersion = "26.05";

  # Environment that zsh/exports.zsh also sets. Duplicated on purpose: these
  # need to exist for graphical apps started by sway (which never source
  # ~/.zshrc), not just for shells.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    MOZ_ENABLE_WAYLAND = "1";
    GTK_USE_PORTAL = "0";
    XDG_CURRENT_DESKTOP = "sway";
    LESS = "-RFX";
  };

  # ~/.local/bin and ~/bin are on PATH via zsh/path.zsh; add them here too so
  # non-shell launchers (wofi, sway bindings) find scripts dropped there.
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.npm-packages/bin"
  ];

  # Let home-manager manage the systemd user session bits it needs (it restarts
  # changed user units on activation).
  systemd.user.startServices = "sd-switch";

  programs.home-manager.enable = true;
}
