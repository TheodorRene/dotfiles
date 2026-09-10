# Bluetooth. sway/config starts blueman-applet at login, which keeps bluez
# D-Bus-activated so blueman-manager opens fast.
{ config, lib, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # Headset battery reporting, used by waybar's pulseaudio/battery display.
    settings.General.Experimental = true;
  };

  # libspa-0.2-bluetooth on Ubuntu; on NixOS the PipeWire bluetooth backend is
  # part of the pipewire package — nothing extra to install.
  services.blueman.enable = true;
}
