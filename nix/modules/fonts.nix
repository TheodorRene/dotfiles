# Fonts. waybar/style.css, kitty, alacritty, mako and swaylock all name
# "JetBrainsMono Nerd Font" explicitly — without it the bar loses its icons.
# On Ubuntu this was a manual nerdfonts.com download into
# ~/.local/share/fonts + fc-cache (REINSTALL.md §3.5); here it's a package.
{ config, lib, pkgs, ... }:

{
  fonts = {
    enableDefaultPackages = true;

    packages = with pkgs; [
      # If your nixpkgs predates the nerd-fonts split (< 24.11), this is
      # (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) instead.
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji # $mod+e emoji picker needs a colour emoji font
      noto-fonts-cjk-sans
      liberation_ttf
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font Mono" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
