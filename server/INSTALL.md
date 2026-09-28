# Installing NixOS on the Spectre, from a blank disk to an SSH you can reach from your phone

**Status: Nothing applied (2026-09-22).** Nobody has run any of this. The three
Nix files below have been **syntax-checked** (`nix-instantiate --parse`, all
three parse) but have **never been evaluated against nixpkgs**, so option
*names* are unverified — `services.logind.settings.Login` in particular is the
post-25.11 spelling and the older one is `services.logind.lidSwitch`. Expect the
first `nixos-install` to reject something; that is normal and it tells you what.

This is Phase 1 of `README.md` and nothing more: a machine that boots, stays up,
and is reachable. No apps, no containers, no OpenClaw.

Plan for an evening, most of it waiting on downloads.

---

## What you need

| | |
|---|---|
| A USB stick | 4 GB is plenty; its contents will be destroyed |
| The USB3 ethernet adapter | The minimal ISO is console-only; wifi means `wpa_supplicant` by hand |
| Your phone | To approve the Tailscale login, and to prove SSH works from outside |
| A decided hostname | It appears in three files; renaming later is a chore. See `README.md` |
| ~30 min of attention, plus download time | |

---

## Stage 0 — write the config first, here

**The USB session should be short and boring.** Everything below can be written,
committed and pushed from a comfortable chair before the Spectre is even plugged
in. `github.com/TheodorRene/dotfiles` is public (verified 2026-09-22), so the
installer can `git clone` it with no keys, no tokens and nothing copied onto the
stick.

Three files. Replace `NAME` with the hostname throughout.

### `server/flake.nix`

```nix
{
  description = "NAME — home server";

  inputs = {
    # Stable, deliberately — the opposite of nix/flake.nix, and for the opposite
    # reason: this is 2018 hardware that needs nothing new from a kernel, and an
    # always-on box is the worst place for an unstable channel's breakage.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations.NAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/NAME
      ];
    };
  };
}
```

### `server/hosts/NAME/disks.nix`

No LUKS (decided — see `README.md`). btrfs stays, because snapper and btrbk in
Phase 2 are btrfs features.

```nix
{
  disko.devices.disk.main = {
    # NEVER /dev/nvme0n1 here — kernel names can move between boots. Get the
    # stable id in the installer with:  ls -l /dev/disk/by-id/
    device = "/dev/disk/by-id/REPLACE-ME";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        # 1 GB, not 512 MB: NixOS keeps several generations of kernels on the
        # ESP, and those generations are the entire rollback story.
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
            subvolumes = {
              "/root" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/var" = { mountpoint = "/var"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
              # Everything imperative lives here — see README.md's rule for
              # keeping a mixed declarative/imperative setup honest.
              "/srv" = { mountpoint = "/srv"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/snapshots" = { mountpoint = "/.snapshots"; mountOptions = [ "compress=zstd" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
```

### `server/hosts/NAME/default.nix`

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware.nix ./disks.nix ];

  networking.hostName = "NAME";
  # The release you install from. Set once, never bump — it is not a version
  # number, it's a statement about which defaults this machine's state matches.
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep plenty of generations: on a headless box the boot menu IS the recovery
  # plan, and with no LUKS there is nothing else to fall back to.
  boot.loader.systemd-boot.configurationLimit = 20;

  # --- A server does not sleep -----------------------------------------------
  # Both halves matter: logind stops the lid from triggering suspend, and
  # disabling the targets means nothing else can reach it either.
  # NOTE: this is the post-25.11 spelling. Older channels want
  # `services.logind.lidSwitch = "ignore";` etc.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # --- Network ---------------------------------------------------------------
  networking.useDHCP = lib.mkDefault true;
  networking.firewall = {
    enable = true;
    # The entire security model: services bind normally, and only the tailnet
    # can reach them. Nothing is open to the LAN or the WAN.
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";   # needed if it ever becomes an exit node
  };

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;         # reachable over tailscale0 only
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.trc = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Put the PUBLIC key of whatever you'll connect FROM. Get it wrong and the
    # physical keyboard is your way back in — which is fine, it's in the flat.
    openssh.authorizedKeys.keys = [ "ssh-ed25519 REPLACE-ME" ];
  };

  zramSwap = { enable = true; memoryPercent = 50; };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
  '';

  environment.systemPackages = with pkgs; [ git vim htop tmux ];
}
```

`hardware.nix` is generated on the machine in Stage 4 — leave it out for now.

Commit and push. **Untracked files do not exist to a flake** (see Gotchas), so
anything not committed won't be installed.

---

## Stage 1 — write the USB

Get the **minimal ISO** (console, ~1 GB) from <https://nixos.org/download/> —
"Minimal ISO image", x86_64. Not the graphical one; this is a server.

`sudo` can't be driven from Claude Code, so **run these yourself**:

```bash
# 1. find the stick. Check the SIZE column, twice. This is the destructive step.
lsblk

# 2. verify what you downloaded (the hash is on the download page)
sha256sum nixos-minimal-*-x86_64-linux.iso

# 3. write it — note of=/dev/sdX is the DISK, not a partition like /dev/sdX1
sudo dd if=nixos-minimal-*-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## Stage 2 — BIOS, before anything else

Power on and press **`Esc`** (HP's menu) or **`F10`** for setup; **`F9`** is a
one-time boot menu.

1. **Disable Secure Boot.** The NixOS ISO will not boot with it enabled.
2. Confirm the storage mode is **AHCI/NVMe**, not RAID or Intel Optane.
3. While you're in here, answer one of `README.md`'s open questions: **is there a
   "Power on after AC loss" / "AC Recovery" option?** This is the only place
   that's answerable, and it caps how much anything should depend on the machine.

---

## Stage 3 — live session, before touching the disk

Plug in the **USB ethernet adapter** and boot the stick.

**First, get anything off the disk that matters.** This is an old personal
laptop; assume there are photos on it until you have checked. Everything after
this point is irreversible.

Then run the inventory — you're sitting there anyway, and nothing in the install
depends on its answers, so this is one trip rather than two:

```bash
curl -sL https://raw.githubusercontent.com/TheodorRene/dotfiles/main/server/inventory.sh | bash | tee /tmp/inventory.txt
```

Read the battery section before continuing. **A swollen cell is a stop-work
condition**, not a note for later.

If you have no ethernet adapter, wifi on the minimal ISO is roughly:

```bash
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YOUR-SSID"
> set_network 0 psk "YOUR-PASSWORD"
> enable_network 0
> quit
```

---

## Stage 4 — partition and install

```bash
# the config
git clone https://github.com/TheodorRene/dotfiles /tmp/dotfiles
cd /tmp/dotfiles

# the disk's stable id — put this in disks.nix as device = "/dev/disk/by-id/..."
ls -l /dev/disk/by-id/
$EDITOR server/hosts/NAME/disks.nix

# partition + format + mount, declaratively. DESTROYS the disk.
sudo nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode destroy,format,mount \
  server/hosts/NAME/disks.nix

# sanity check before going further: / /boot /nix /home /srv all mounted?
findmnt -R /mnt

# hardware facts. --no-filesystems because disko already declares them;
# without it you get a second, conflicting fileSystems block.
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix server/hosts/NAME/hardware.nix

# THE STEP EVERYONE FORGETS — a flake cannot see untracked files
git add -A

sudo nixos-install --flake /tmp/dotfiles/server#NAME
```

It will ask for a **root password** at the end. Set one you can type at a
physical keyboard — it's the way back in if SSH doesn't work.

```bash
reboot          # pull the USB stick as it goes down
```

---

## Stage 5 — first boot, and the three things that prove it worked

Log in at the keyboard as `root`, then:

```bash
passwd trc          # the user has no password yet; it needs one for local login
tailscale up        # prints a URL — approve it on your phone
tailscale status    # should show the node with an address
```

In the Tailscale admin console: **disable key expiry for this node.** The
180-day default will otherwise silently drop the server off the tailnet months
from now, and it will present as a network fault.

Now prove the three properties that make it a server rather than a laptop:

| # | Test | Why it's the test |
|---|---|---|
| 1 | `ssh trc@NAME` **from your phone on mobile data**, not the home wifi | Proves the tailnet, not the LAN |
| 2 | **Pull the power cord, wait, plug it back in.** It must return to a reachable SSH with nobody touching it | This is the whole point of the machine. If it stops at a passphrase prompt or a BIOS setting, find out now |
| 3 | **Close the lid.** It must stay up | Proves both halves of the sleep config |

Finally, push `hardware.nix` back so the repo describes the real machine:

```bash
cd /tmp/dotfiles && git add server/hosts/NAME/hardware.nix && git commit && git push
```

(Clone it to a permanent path first — `/tmp` is a bad home for the config. `/srv`
or `~/dotfiles` on the server.)

After this, physical access is optional: everything is
`sudo nixos-rebuild switch --flake ~/dotfiles/server#NAME` over SSH.

---

## Gotchas

- **Flakes ignore untracked files.** Edit `hardware.nix`, forget `git add`, and
  `nixos-install` silently uses the old version — or fails to find the file at
  all. The error message never says "you forgot to git add". Inside the clone,
  `git add -A` before every install or rebuild.
- **`nixos-generate-config` without `--no-filesystems`** emits a `fileSystems`
  block that fights disko's. Two definitions, one error, confusing message.
- **`/dev/nvme0n1` in `disks.nix`** — kernel names are not stable across boots.
  Use `/dev/disk/by-id/...`.
- **A 512 MB ESP** fills up after a handful of generations, and generations are
  the rollback plan. 1 GB.
- **Secure Boot on** = the ISO won't boot, with an unhelpful message.
- **`system.stateVersion`** is not a version to keep current. Set it once at
  install and never touch it again.
- **`services.logind.settings.Login`** is the post-25.11 spelling; older
  channels use `services.logind.lidSwitch`. If the build complains about an
  unknown option, this is the first place to look.
- **Don't test SSH from the home wifi and call it done.** That may be working
  over the LAN. Mobile data is the real test.

## If it goes wrong

The same USB stick is the rescue disk. Boot it, then:

```bash
sudo nix run github:nix-community/disko -- --mode mount server/hosts/NAME/disks.nix
sudo nixos-enter --root /mnt          # a shell inside the installed system
```

From there you can edit the config and `nixos-rebuild boot` without reinstalling.

If the system boots but is broken, you don't need the USB at all: **pick an
older generation in the boot menu.** That's what `configurationLimit = 20` is
for.

## Reversing it

There is no undo — Stage 4 destroys the existing install. Reversal means
reinstalling whatever was there before from its own media. That's the reason
Stage 3 leads with getting data off the disk.

## What's next

`README.md`'s Phase 2: the external disk, snapper + btrbk, and restic to
somewhere offsite — **and a restore actually performed**, because an untested
restore isn't a backup. Nothing that stores data gets installed before that.
