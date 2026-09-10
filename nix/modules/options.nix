# A tiny `local.*` namespace for the handful of facts that differ between
# machines. Everything else in modules/ is host-agnostic; if you find yourself
# wanting an `if hostname == …` anywhere, add a knob here instead.
{ lib, ... }:

{
  options.local = {
    btrfsLayout = lib.mkEnableOption ''
      the btrfs snapshot/send-receive backup layers (snapper + btrbk + scrub).
      Set by the host's disk-layout module — see modules/backup.nix
    '';

    zramMaxGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 16;
      description = ''
        Cap on the *uncompressed* size of the zram swap device, in GiB. Rule of
        thumb: about half of physical RAM (at ~3:1 compression on dev heaps that
        costs a sixth of RAM in real pages). 16 on a 30 GB machine.
      '';
    };

    intelForceProbe = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "b080";
      description = ''
        Mesa refuses to drive Intel GPUs whose PCI id it doesn't recognise yet.
        Set this to the id (`lspci -nn | grep -i vga`) to force it, or leave null
        on any GPU mesa already knows. Retest with `glxinfo -B` after a nixpkgs
        bump and drop it when it's no longer needed.
      '';
    };
  };
}
