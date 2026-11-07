# Whole-disk layout, applied by disko. Running it DESTROYS EVERYTHING on the
# disk, Windows and the Manjaro install included (see INSTALL.md, Stage 3).
#
# No LUKS (decided, see README.md). btrfs stays, because snapper and btrbk in
# Phase 2 are btrfs features. Swap is zram (default.nix), so there's no swap
# subvolume.
{
  disko.devices.disk.main = {
    # The 512 GB Samsung PM961 (MZVLW512HMJP-000H1), read off the machine on
    # 2026-11-07. NEVER /dev/nvme0n1 here; kernel names can move between boots.
    # Re-check in the installer with `ls -l /dev/disk/by-id/`. If udev names it
    # differently there, `nvme-eui.002538bb61b5d443` is the same disk.
    device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLW512HMJP-000H1_S36ENX0HB49001";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # 1 GB, not 512 MB: systemd-boot keeps a kernel + initrd per generation
        # on the ESP, and those generations are the entire rollback story.
        ESP = {
          priority = 1;
          start = "1M";
          end = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes =
              let opts = [ "compress=zstd" "noatime" ];
              in {
                "/root" = { mountpoint = "/"; mountOptions = opts; };
                "/nix" = { mountpoint = "/nix"; mountOptions = opts; };
                "/var" = { mountpoint = "/var"; mountOptions = opts; };
                # Split out of /var so snapshots of service state don't carry
                # journal churn or re-pullable container layers (Phase 4,
                # rootful podman via oci-containers).
                "/var/log" = { mountpoint = "/var/log"; mountOptions = opts; };
                "/var/lib/containers" = { mountpoint = "/var/lib/containers"; mountOptions = opts; };
                "/home" = { mountpoint = "/home"; mountOptions = opts; };
                # Everything imperative lives here; see README.md's rule for
                # keeping a mixed declarative/imperative setup honest.
                "/srv" = { mountpoint = "/srv"; mountOptions = opts; };
                # No top-level snapshots subvolume: snapper creates a nested
                # .snapshots per config (/srv, /home, /var/lib are the ones
                # worth it; / rolls back through generations instead). Phase 2.
              };
          };
        };
      };
    };
  };
}
