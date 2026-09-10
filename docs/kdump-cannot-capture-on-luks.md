# kdump reserves 512 MB for a dump it can never write

**Status: nothing here is applied.** This is a finding plus the commands to act on
it. Established 2026-09-03 on kernel 7.0.0-30-generic.

**The finding:** `kdump-tools` is enabled and armed, and reserves 512 MB of RAM
permanently. Its crash-capture initrd has no LUKS support, and `/var/crash` lives
inside LUKS. So the capture kernel cannot mount the directory it is supposed to
write to. It has never produced a dump and, as configured, never can.

## How kdump is meant to work

`crashkernel=…4G-32G:512M` (from `/etc/default/grub.d/kdump-tools.cfg`) makes the
kernel carve out 512 MB at boot and never allocate from it. `kdump-tools.service`
then preloads a second kernel + initrd into that region with `kexec -p`:

```
$ cat /var/crash/kexec_cmd
/sbin/kexec -p --command-line="BOOT_IMAGE=/vmlinuz-7.0.0-30-generic
  root=/dev/mapper/ubuntu--vg-ubuntu--lv ro quiet splash reset_devices
  systemd.unit=kdump-tools-dump.service nr_cpus=1 irqpoll usbcore.nousb"
  --initrd=/var/lib/kdump/initrd.img /var/lib/kdump/vmlinuz
```

On a panic the dying kernel jumps straight into that preloaded kernel. Because it
lives in memory the crashed kernel was never allowed to touch, the old kernel's RAM
is still intact and dumpable. The capture kernel boots, mounts
`KDUMP_COREDIR=/var/crash`, and `makedumpfile` writes a `vmcore` for later analysis.

It is currently armed:

```
$ cat /sys/kernel/kexec_crash_size    # 512M reserved
$ cat /sys/kernel/kexec_crash_loaded  # 1  -> capture kernel is in place
```

## Why it cannot work here

`/var/crash` is on `ubuntu--vg-ubuntu--lv` → `dm_crypt-0` → LUKS on `nvme0n1p8`.
The capture kernel must therefore unlock LUKS before it can write anything.

```bash
lsinitramfs /var/lib/kdump/initrd.img-7.0.0-30-generic   # 793 entries
```

| needed to unlock LUKS | present |
|---|---|
| `cryptsetup` binary | **no** |
| `dm-crypt` module | **no** |
| `/etc/crypttab` | **no** |
| `cryptroot` boot script | **no** |
| `lvm` binary, `lvm.conf`, lvm udev rules | yes |

Grepping that listing for `crypt` is a trap — it returns 12 hits, but they are all
`libcrypt.so.1`, `libcrypto.so.3`, and `kernel/crypto/async_tx/*` (RAID helpers).
None of them unlock anything. Grep for `sbin/cryptsetup` and `dm-crypt` instead.

And dm-crypt is not compiled in either, so shipping it in the initrd is mandatory:

```
$ grep DM_CRYPT /boot/config-7.0.0-30-generic
CONFIG_DM_CRYPT=m
```

## The mechanism — a cross-wiring nobody chose

The root cause is a clean one, and it explains why LVM made it in and dm-crypt
did not:

1. **The real boot initrd is dracut.** (See
   [luks-boot-emergency-shell.md](luks-boot-emergency-shell.md) — this machine has
   no initramfs-tools boot path.)
2. **But kdump-tools builds its capture initrd with initramfs-tools**, out of its
   own private config tree at `/var/lib/kdump/initramfs-tools/` (`MODULES=dep`).
   `initramfs-tools-bin` and `initramfs-tools-core` *are* installed for exactly
   this reason.
3. **initramfs-tools gets LUKS support from the `cryptsetup-initramfs` package**,
   which is **not installed**. Present are `cryptsetup`, `cryptsetup-bin`,
   `libcryptsetup12` and `systemd-cryptsetup` — none of which provide the hook.
4. Confirm by listing the hooks: `/usr/share/initramfs-tools/hooks/` contains
   `lvm2` but **no `cryptroot`**. Hence LVM, no LUKS.

Nobody misconfigured this. Because the boot initrd is dracut, nothing on the system
ever needed `cryptsetup-initramfs` to exist, and kdump silently inherited the gap.

Consistent with all of the above: `/var/crash` contains no `vmcore`, only an
apport crash from `blueman-applet`. It has never captured anything.

## What it costs

- **512 MB of RAM**, permanently. `MemTotal: 31887952 kB` is already net of it.
- **63 MB of disk** in `/var/lib/kdump` — two 31 MiB initrds, rebuilt every kernel update.
- ~230 ms of boot (`kdump-tools.service`, per `systemd-analyze blame`).

## Options

### Disable it — the recommendation, since it cannot work

```bash
# 1. release the 512 MB back immediately, no reboot needed
echo 0 | sudo tee /sys/kernel/kexec_crash_size

# 2. make it permanent
sudo systemctl disable --now kdump-tools
sudo rm /etc/default/grub.d/kdump-tools.cfg && sudo update-grub
```

**Those are two separate steps for a reason.** `systemctl disable --now` only
unloads the capture kernel; it does **not** release the reservation, because the
reservation is made by the kernel from `crashkernel=` on the cmdline at boot. The
write to `kexec_crash_size` is what actually hands the memory back in the running
system.

### Or make it work, if crash dumps are wanted

```bash
sudo apt install cryptsetup-initramfs
```

…then regenerate the kdump initrd. But consider what that buys: after a panic, the
capture kernel would come up and **prompt for the LUKS passphrase on a crashed
machine** before it could write the dump. Workable, not pleasant.

The alternative is pointing `KDUMP_COREDIR` at unencrypted `/boot` (`nvme0n1p7`,
2.0G, 1.7G free). That is a gamble: a `vmcore` from 30 GB of RAM, even with
`makedumpfile -d 31`, may not fit.

## Caveat on the memory angle

512 MB is ~1.7% of RAM. This will **not** fix the `systemd-oomd`-kills-the-session
problem described in `CLAUDE.md` — that is a memory-*pressure* threshold issue, not
a headroom issue, and the mitigations for it are the zram + oomd tuning already
applied. Reclaiming this is worth doing because the facility is structurally
incapable of working, not because 512 MB solves anything.

## Re-verifying, if this is ever revisited

```bash
cat /sys/kernel/kexec_crash_size /sys/kernel/kexec_crash_loaded
lsinitramfs /var/lib/kdump/initrd.img-$(uname -r) | grep -E 'sbin/cryptsetup|dm-crypt'
ls /usr/share/initramfs-tools/hooks/ | grep cryptroot
dpkg -l | grep cryptsetup-initramfs
find /var/crash -name 'vmcore*'
```

Empty output from the middle three is the finding.
