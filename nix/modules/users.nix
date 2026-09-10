# The user account.
{ config, lib, pkgs, ... }:

{
  # zsh must be enabled system-wide, not just installed, or it won't be a valid
  # login shell (/etc/shells) and the session will fall back to bash.
  programs.zsh.enable = true;
  # ~/.zshrc from this repo does its own compinit, prompt and plugin loading, so
  # keep NixOS' additions out of the way — no framework, as CLAUDE.md says.
  programs.zsh.enableCompletion = false;
  programs.zsh.promptInit = "";

  users.users.trc = {
    isNormalUser = true;
    description = "Theodor René Carlsen";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video" # brightnessctl's udev rule — the XF86MonBrightness bindings
      "input" # keyboard LEDs, and evdev tools like wev
      "audio"
      "docker"
      "plugdev" # YubiKey
      "lp" # printing
      "dialout"
    ];
    # Set on first boot with `passwd`, or pre-seed a hash here with
    # `hashedPassword = "$y$...";` (mkpasswd -m yescrypt). Autologin means you
    # rarely type it — but sudo and swaylock both need it.
  };

  # Keep `passwd`/`usermod` usable; declaring users immutably would mean a
  # rebuild for every password change and locks you out of rescue fixes.
  users.mutableUsers = true;
}
