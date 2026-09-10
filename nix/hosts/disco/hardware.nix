# Machine-specific hardware for disco. The Intel iGPU/microcode/thermald bits are
# shared — see ../../modules/hardware-intel.nix — and driven by
# `local.intelForceProbe`, set in ./default.nix.
{ config, lib, pkgs, ... }:

{
  # The panel advertises exactly one mode (1920x1200@120), so there is nothing to
  # configure here — kanshi/config drives output layout.

  # NOTE: the IPU7 camera (intel-ipu7-dkms on Ubuntu) has no nixpkgs module —
  # `hardware.ipu6` covers IPU6 only. Expect the webcam not to work until ipu7
  # lands upstream. See ../../docs/ubuntu-to-nixos.md.

  # Virtual camera for Kooha/OBS-style workflows (v4l2loopback-dkms on Ubuntu).
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
}
