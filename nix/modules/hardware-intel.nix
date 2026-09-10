# Shared Intel CPU + integrated graphics support. Imported by any host with an
# Intel iGPU; per-machine quirks go through `local.*` (see ./options.nix).
{ config, lib, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API (iHD)
      vpl-gpu-rt # oneVPL runtime, hardware video encode
      intel-compute-runtime # OpenCL
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  } // lib.optionalAttrs (config.local.intelForceProbe != null) {
    INTEL_FORCE_PROBE = config.local.intelForceProbe;
  };

  # Intel thermal management — thin laptop chassis throttle hard without it.
  services.thermald.enable = true;
}
