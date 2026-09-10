# Memory pressure design: zram-primary swap + oomd that kills on sustained PSI
# pressure rather than on swap fullness, + VM sysctls tuned for that layout.
#
# This is the declarative equivalent of scripts/install-oomd-tuning.sh and
# scripts/install-perf-tuning.sh, and the comments from
# etc/systemd/{zram-generator.conf,oomd.conf.d/override.conf,
# system/user.slice.d/50-oomd.conf} and etc/sysctl.d/99-vm-tuning.conf are
# carried over — they're the reasoning, not decoration.
{ config, lib, pkgs, ... }:

{
  # --- zram ------------------------------------------------------------------
  # A heavy dev load (.NET in docker + webpack/node + cargo/rustc + browser) on
  # 30 GB was overshooting by a few GB, and oomd killed the whole graphical
  # session (everything shares one session cgroup, so the only thing it can
  # evict is all of it). zram buys effective headroom by compressing swapped
  # pages in RAM (~3:1 on dev heaps).
  #
  # memoryMax caps the *uncompressed* size (16 GiB on disco ≈ 5 GB of real RAM
  # at 3:1, matching zram-size = 16384 in the Ubuntu config); memoryPercent = 100
  # just keeps the percentage rule from biting first. Per-host, because it should
  # track physical RAM — see local.zramMaxGiB in ../modules/options.nix.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
    memoryMax = config.local.zramMaxGiB * 1024 * 1024 * 1024;
    priority = 100;
  };

  # The 8 GB disk swap file (priority -1, strictly a backstop behind zram) is
  # declared with each host's disk layout, because its path and the btrfs
  # nodatacow requirement belong to the filesystem, not here.

  # --- systemd-oomd ----------------------------------------------------------
  systemd.oomd = {
    enable = true;
    # Kill on sustained memory *pressure* in the user session…
    enableUserSlices = true;
    # …and never on swap fullness: with zram, swap fills cheaply by design, so
    # swap% is a meaningless distress signal (ManagedOOMSwap=kill on the root or
    # system slice would nuke things the moment zram warms up).
    enableRootSlice = false;
    enableSystemSlice = false;
  };

  # 60% for 20s: the upstream-sane values. The hair-trigger 40%/10s tried
  # earlier killed the session prematurely.
  systemd.oomd.settings.OOM = {
    DefaultMemoryPressureLimit = "60%";
    DefaultMemoryPressureDurationSec = "20s";
  };

  # …and override the *per-slice* limit, which is what actually applies. NixOS'
  # oomd module pins ManagedOOMMemoryPressureLimit to (mkDefault) 80% on
  # user.slice, which silently wins over the 60% default above — and at 80%
  # pressure the session has been thrashing for a while already. A plain
  # assignment beats their mkDefault.
  systemd.slices."user".sliceConfig.ManagedOOMMemoryPressureLimit = "60%";

  # Same 80% is hardcoded for slices *inside* the user manager; it's raw unit
  # text upstream, so replacing it takes mkForce.
  systemd.user.units."slice".text = lib.mkForce ''
    [Slice]
    ManagedOOMMemoryPressure=kill
    ManagedOOMMemoryPressureLimit=60%
  '';

  # --- VM sysctls ------------------------------------------------------------
  boot.kernel.sysctl = {
    # No swap read-ahead: zram is RAM-speed random access, so faulting in 8
    # pages per fault just burns CPU decompressing pages we won't use.
    "vm.page-cluster" = 0;

    # Prefer compressing cold anon pages into zram over evicting file cache
    # (source trees, node_modules, LSP/parser caches). 100–180 is sane for zram.
    "vm.swappiness" = 150;

    # Retain dentry/inode cache harder — huge dir trees (pnpm/node_modules,
    # cargo target/) make directory metadata expensive to re-fetch.
    "vm.vfs_cache_pressure" = 50;

    # Wake kswapd earlier so reclaim happens in the background instead of as
    # latency-spiking direct reclaim (and fewer oomd session kills).
    "vm.watermark_scale_factor" = 100;
  };

  # Optional next step, still unapplied on Ubuntu (docs/rust-analyzer-memory-cap.md):
  # cap the repeat OOM offender in its own slice instead of letting it compete
  # with the whole session. Uncomment and start rust-analyzer inside it.
  # systemd.user.slices."rust-analyzer" = {
  #   description = "rust-analyzer, memory-capped";
  #   sliceConfig = { MemoryHigh = "6G"; MemoryMax = "8G"; };
  # };
}
