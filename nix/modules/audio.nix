# Audio: PipeWire, as on Ubuntu (pipewire + wireplumber + pipewire-pulse).
# scripts/volume.sh drives wpctl, so wireplumber must be the session manager.
{ config, lib, pkgs, ... }:

{
  security.rtkit.enable = true; # lets PipeWire get RT priority

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # pavucontrol, and anything still speaking PulseAudio
    wireplumber.enable = true;
  };
}
