# A 2018/2019 HP Spectre x360 as an always-on home server

**Status: Nothing applied (2026-09-22).** Design + runbook. No NixOS is installed
on the Spectre, and no Tailscale account is in use.

**Almost every hardware fact below is assumed, not verified.** Nobody has run a
command on that laptop yet. `./inventory.sh` turns the assumptions into facts —
run it first, fill in "Hardware", then re-read the decisions that depend on it.
Assumptions are marked **(assumed)**.

---

## Scope: this machine only

The server is **its own thing**. It is not an accessory to the XPS this repo
otherwise configures, it doesn't back that machine up, and it isn't monitored
alongside it. It gets its own flake, its own hostname, its own reasons to exist.
Anything that later connects the two is a separate decision, made separately.

That means, concretely:

```
server/
├── README.md        this plan — decisions, what to run, order of work
├── INSTALL.md       Phase 1, step by step: USB → BIOS → disko → first boot
├── inventory.sh     run it on the Spectre; fills in the hardware table
└── flake.nix        ← the machine's own flake, plus hosts/ (doesn't exist yet;
                       the three files to write are in INSTALL.md, Stage 0)
```

**Its own flake, not a host inside `nix/`.** The reasoning:

- `nix/` is an **unbuilt draft for a laptop that does not exist** — never
  installed, never booted, probably never evaluated. Hanging a real machine off
  an untested tree means debugging two things at once, forever.
- A headless server and a Sway workstation share almost nothing worth sharing.
  The overlap is `locale`, `nix-daemon`, a package list — a few dozen lines. The
  divergence is everything else.
- Independent flakes means independent `flake.lock`s: an update that breaks the
  laptop config can't break the server, and vice versa.

**A flake can only see files under its own root**, so `server/flake.nix` cannot
reach `../nix/` and `nix/flake.nix` cannot reach here. That's the desired
property, not an obstacle — the separation is enforced by the tool.

`nix/modules/` is still worth *reading* for ideas (`backup.nix` in particular has
its reasoning written out). Copy what applies; import nothing. Three traps if you
do copy:

1. `security.nix` sets `services.openssh.enable = false` as a **plain**
   definition, not `mkDefault` — enabling it elsewhere is a conflicting
   definition, not an override.
2. `common.nix` pulls in the whole desktop (sway, GDM, PipeWire, fonts) and
   `services.nix` enables CUPS + Avahi. A headless box wants none of it.
3. `nix-daemon.nix` is tuned for 16 cores. This machine has four **(assumed)**.

---

## Hardware (fill this in)

Run `inventory.sh` on the Spectre — its current OS, an Ubuntu live USB, or the
NixOS installer ISO all work. If it's still on Windows, boot a live USB; the
script only reads `/sys` and `/proc`.

| Fact | Assumed | Actual |
|---|---|---|
| Model / chassis | 13" `13-ap0xxx` **(assumed)** | |
| CPU | i5-8265U or i7-8565U, 4C/8T **(assumed)** | |
| RAM | 8 or 16 GB, **soldered — not upgradable** **(assumed)** | |
| Disk | one NVMe, 256–512 GB **(assumed)** | |
| iGPU | Intel UHD 620, QuickSync ⇒ hardware H.264/HEVC transcode **(assumed)** | |
| dGPU | none on the 13"; the 15" `15-df` has an MX150/GTX 1050 Ti **(assumed none)** | |
| Wired ethernet | **none — USB-C/USB-A only** | |
| Battery health | unknown; **6–7 years old** | |
| BIOS: power-on after AC loss | unknown — check F10 setup | |

Three of these change the plan materially:

- **RAM.** 8 GB caps what can run at once — Immich and Jellyfin and a metrics
  stack on 8 GB is a swap-thrash machine. 16 GB is comfortable. Soldered, so
  this is not fixable later.
- **dGPU.** A 15" with a 1050 Ti moves local LLM inference from "pointless" to
  "small models at usable speed". The 13" doesn't.
- **Disk size.** Anything that accumulates — photos, media — needs external
  storage; see "Storage".

---

## Why a laptop is a good server, and the five ways it bites

Good: it's free, quiet, idles at maybe 5–10 W, **and it has a built-in UPS.** A
desktop or Pi dies at a power blip; this one keeps running. It also has a screen
and keyboard physically attached, which makes "I broke networking with a bad
rebuild" a two-minute walk rather than an outage — that alone justifies being
braver here than on a rented box.

The costs:

1. **The lid.** Closing it suspends by default, and suspending is death for a
   server. `logind` must ignore the lid on AC *and* battery, and the sleep,
   suspend, hibernate and hybrid-sleep targets should be disabled outright —
   belt and braces, so no module's default quietly re-enables a path.
2. **The battery.** A 6–7 year old cell held at 100% and 35 °C is the most likely
   hardware failure here, and a swollen one in a sealed chassis is a real fire
   risk, not a hypothetical. **Inspect it physically** — does the bottom panel
   sit flat, does the trackpad click normally — before committing the machine to
   unattended 24/7 duty. If a charge ceiling is exposed
   (`/sys/class/power_supply/BAT*/charge_control_end_threshold`), cap it at
   60–80%. HP's support for that control is inconsistent; `inventory.sh` checks
   rather than assumes.
3. **No wired port.** A server on wifi drops transfers mid-stream. Use a **USB3
   gigabit adapter** (~£10) and a static DHCP lease.
4. **One disk, no ECC, no IPMI.** It is not a NAS. Nothing irreplaceable should
   live only here — which is why backups come before any service that stores
   things.
5. **Thermals in a thin chassis.** Sustained load throttles. Leave the **lid
   open** (free once the lid switch is ignored, and it helps the hinge vents)
   with the console blanked.

---

## Decided: no disk encryption

**Decision (2026-09-22): the server's disk is not encrypted.** Plain GPT → ESP →
btrfs, no LUKS.

Why: **an encrypted root means every boot stops and waits for a human to type a
passphrase.** After a power cut at 3 a.m. the machine does not come back, which
defeats most of the point of an always-on box. A lot of complexity goes with it —
no TPM2 enrolment, no PCR policy that breaks on the next firmware update, no
crypttab, nothing extra in the initrd on a machine whose whole job is returning
by itself.

**What it costs, plainly:** the disk is readable by anyone who takes the machine
or pulls the NVMe. For a laptop at home that's an accepted risk, with two
consequences worth writing down before they're rediscovered:

- **Anything stored here is stored in the clear.** That's fine for media and for
  a metrics database; it's worth a thought before the machine holds the only copy
  of documents or photos. Services with client-side crypto (Vaultwarden derives
  its keys from the master password, so its DB stays opaque) are unaffected.
- **Outbound backups must be encrypted client-side.** restic repos are, which is
  what makes an unencrypted server safe to back up *from* — the passphrase never
  goes into the repo. See "Backups".
- **The Tailscale node key is plaintext on that disk**, so whoever takes the
  machine can join the tailnet as it. Scope the node with tailnet ACLs and remove
  it from the admin console if the machine ever walks.

Also now moot: TPM2 auto-unlock, and remote unlock over SSH in the initrd (which
was already a dead end — `tailscaled` doesn't exist in the initrd — and now has
nothing to unlock).

**btrfs stays**, though. Dropping LUKS drops one layer, not the filesystem:
snapper timeline snapshots answer "that service config worked an hour ago", and
btrbk send/receive is the cheapest way to get a second copy onto an external
disk. Swap is zram; a swapfile on btrfs would need `nodatacow`.

---

## Decided: NixOS base, containers for the apps

**Decision (2026-09-22): the middle path.** NixOS owns the machine; container
images own the applications. Not "NixOS all the way down", and not "Debian +
Compose like everyone else".

| Layer | Owned by | Why |
|---|---|---|
| Boot, disks, users, sshd, Tailscale, firewall, systemd units **and their hardening**, backups | **Nix**, in `server/flake.nix` | Must survive a reinstall, must be reviewable, must roll back |
| Immich, Jellyfin, Paperless — anything upstream ships an image for | **Podman/Docker**, declared via `virtualisation.oci-containers` | App-layer software churns faster than nixpkgs; upstream's *supported* path is Compose |
| OpenClaw | **imperative install, Nix-declared unit** | See its own section below |

The honest case for the alternative, recorded so it isn't re-argued: **Debian
stable + Docker Compose is what most home servers are**, and it isn't a
compromise — every project on the service list ships a compose file as its
supported path, and the nixpkgs modules are a community translation of it. Immich
is the sharp example: it updates often and ships breaking DB migrations, and when
a NixOS module lags a release you are the one holding it.

What NixOS buys that's worth the extra concepts, on a headless box specifically:

1. **Rollback.** A bad `apt upgrade` on a machine in a cupboard is a
   walk-over-with-a-monitor evening. A bad `nixos-rebuild` is picking the
   previous generation in the boot menu. For a machine whose whole job is coming
   back by itself, that's worth real effort.
2. **systemd hardening is pleasant to express** — `NoNewPrivileges`,
   `ProtectSystem=strict`, `ReadWritePaths` allowlists — and tedious as unit
   drop-ins. That matters most for exactly the service that needs it most.

Using `virtualisation.oci-containers` rather than a hand-managed
`docker-compose.yml` keeps the *existence* and wiring of each container in git
even though its contents are a pinned image tag. **Pin tags, never `:latest`** —
`:latest` is how a reboot silently becomes an upgrade.

### The rule that keeps a mixed setup honest

Mixed setups fail by **drift**: six months on, nobody remembers which half is
declarative. This repo already has the convention for it — the in-place `/etc`
edits and the `/dev/null` udev mask are documented as *not tracked by the repo,
re-run after a reinstall*. Same discipline here:

> **Everything imperative lives under one directory, is in the backup path, and
> has its exact install command written down.** If a reinstall can't be driven
> from this document plus `nixos-rebuild`, it isn't finished.

---

## Tailscale

Why Tailscale rather than raw WireGuard is already argued in
`docs/claude-code-from-phone.md` (key distribution, NAT traversal with no public
IP, MagicDNS; the free tier covers 100 devices / 3 users). It applies unchanged.
What's specific to a server:

```nix
services.tailscale = {
  enable = true;
  # "server" turns on IP forwarding + the sysctls for exit-node / subnet-router
  # duty. "client" is enough to merely be reachable. Start narrow, widen later.
  useRoutingFeatures = "client";
  # Lets a local reverse proxy fetch HTTPS certs for *.ts.net, if one exists.
  # permitCertUid = "caddy";
};

networking.firewall = {
  enable = true;
  # The whole security model: services bind normally, the firewall makes them
  # reachable only over the tailnet. Nothing is exposed to the LAN or the WAN.
  trustedInterfaces = [ "tailscale0" ];
  # Needed if this ever becomes an exit node; harmless otherwise.
  checkReversePath = "loose";
};
```

**Do the first `tailscale up` by hand.** `authKeyFile` wants a secret that must
not be in git, which means agenix or sops-nix — a framework for a one-time
30-second login. Adopt one the first time something *else* needs a secret.

In the admin console:

- **Disable key expiry for this node.** The 180-day default will otherwise drop
  the server off the tailnet months from now and present as a network fault.
  This is the most common Tailscale-homeserver footgun.
- **MagicDNS on**, so it's `ssh <name>`.
- Optionally **Tailscale SSH** (tailnet identity instead of keys).

**Don't make Tailscale SSH the only way in** — if a rebuild breaks `tailscaled`,
it takes that with it. Run a real `sshd` too, keys only, kept off the LAN by
`trustedInterfaces`:

```nix
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = false;
  settings.KbdInteractiveAuthentication = false;
  openFirewall = false;          # reachable over tailscale0 only
};
users.users.<you>.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
```

**Don't port-forward on the router.** If something genuinely needs to be public
later, that's `tailscale funnel`, which needs no inbound port at all.

---

## Rebuilding it

Simplest thing that works: **the server builds itself** from a git checkout of
`server/` on the machine.

```bash
sudo nixos-rebuild switch --flake /etc/nixos#<name>   # or wherever the checkout lives
```

Four cores is unexciting but adequate for a headless closure, and it keeps the
machine self-contained — no second machine required to fix it. If a build ever
gets heavy enough to hurt, `--target-host` from a faster machine with Nix is
available as a convenience, not a dependency.

Note the layering means **two update paths, deliberately**: `nixos-rebuild` moves
the base, and bumping a pinned image tag (a one-line diff) moves an app. Neither
drags the other along, which is the point — an Immich release with a breaking
migration is not entangled with a kernel bump.

Rules that make rebuilds safe:

- `nixos-rebuild test` first for anything touching networking, firewall or
  tailscale: it activates without changing the boot default, so a power cycle
  undoes it.
- If you lock yourself out: walk to it, pick the previous generation in the boot
  menu. That's the entire disaster-recovery plan.
- **`system.autoUpgrade` against `nixos-unstable` is a bad idea on an always-on
  machine** — it turns a breaking change into a 4 a.m. outage. Track a stable
  release (`nixos-25.11`/`26.05`) rather than unstable; there's no new-hardware
  argument for unstable on a 2018 laptop. A nightly `nixos-rebuild build` that
  fails is a useful alert; an unattended `switch` that half-works is an outage.

---

## Storage

The internal NVMe is small **(assumed 256–512 GB)** and holds the OS. Anything
that accumulates wants external disk over USB3.

- A single **external SSD** is the low-friction choice, and btrfs on it gets
  snapshots and send/receive for free.
- USB enclosures are the weak link — cheap ones drop off under sustained writes
  (UAS resets in `dmesg`). Buy a decent one, mount `nofail` so a missing disk
  never strands the boot.
- **Don't build a RAID from USB disks.** Two independent copies beat a fragile
  array.

---

## Backups

The server will, fairly quickly, hold things that exist nowhere else — that's
what makes a home server useful and also what makes it dangerous. Three layers,
same shape as `nix/modules/backup.nix` argues for, adapted:

1. **snapper** — btrfs timeline snapshots on the same disk. Instant, ~free, and
   the answer to "I broke that config an hour ago". **Not a backup.**
2. **btrbk** — send/receive to the external USB disk. Incremental, so daily runs
   are seconds. Survives the internal NVMe dying.
3. **restic, offsite** — encrypted and deduplicated, to somewhere that isn't this
   flat. B2, Borgbase, a drive at another address. **This is the layer that
   survives fire, theft and burglary**, and it's the one that makes an
   unencrypted server acceptable: the repo is encrypted client-side, so the
   destination never sees plaintext.

**Nothing counts as backed up until a restore has been performed.** Untested
restores aren't backups.

---

## What to run on it

Ranked by how much each earns its keep on a 4-core, 8–16 GB laptop with one
internal disk.

### Tier 1 — the reasons to build it

**1. Photos: Immich.** The actual replacement for Google Photos — phone
auto-upload, albums, ML search for faces and objects. The iGPU does transcoding
**(assumed — verify with `vainfo`)**. This is the service most people find they
use daily. Wants RAM for the ML side and real storage, and it becomes the primary
copy of irreplaceable things almost immediately, so it goes *after* backups work.

**2. Files: Syncthing.** Peer-to-peer sync between phone, laptops and the server,
with the server as the always-on node that makes sync work when everything else
is shut. File-level versioning on the server side is a nicer undo than most apps
provide. Small, boring, reliable — the best first data service.

**3. Tailscale exit node.** Route the phone through home on café and hotel wifi.
One flag (`useRoutingFeatures = "server"` plus approving the route), no ongoing
cost. *Caveat:* home upload bandwidth becomes the phone's ceiling.

**4. Media: Jellyfin.** UHD 620 QuickSync handles H.264/HEVC hardware transcode
**(assumed — `vainfo`)**. Storage-bound rather than CPU-bound, so it lives or
dies on the external disk. Fully free, no licence tier, unlike Plex.

### Tier 2 — good once Tier 1 is steady

- **DNS adblocking** (blocky or AdGuard Home) as the tailnet's resolver. *Caveat:*
  it makes the server a single point of failure for name resolution — scope it to
  the tailnet via split DNS so a reboot doesn't take the LAN's internet with it.
- **ntfy** — self-hosted push to the phone, with no account and no third party.
  Useful the moment anything on the box wants to tell you something (a failed
  backup, a full disk, a finished job).
- **Monitoring of itself**: `services.prometheus.exporters.node` + Prometheus +
  Grafana. Disk temperature and SMART on a 7-year-old NVMe, free RAM, whether the
  thing is thermally throttling in its closed-lid corner. A homeserver that
  silently degrades is the normal failure mode; this is what catches it.
- **Git forge** (Forgejo) for personal repos — a remote you own, and a place for
  the ones that shouldn't be on GitHub.
- **Scheduled jobs.** The box that's always on is the natural home for the small
  recurring things: `nix flake update` + a build to see if it still compiles,
  SMART reports, feed fetching, `restic prune`.
- **Vaultwarden.** Bitwarden-compatible password server; small and pleasant, and
  it raises the stakes on backups more than anything else here.
- **Paperless-ngx** — document archive. Genuinely good if a scanner habit exists;
  otherwise it's an empty database.
- **Binary cache** (`nix-serve` or attic), if the machine ends up rebuilding
  often enough to care.
- **OpenClaw** — see its own section; it's Phase 6, not a Tier 2 afterthought.

### Tier 3 — conditional, or skip

- **Home Assistant** — excellent, but only with smart-home hardware to automate.
  Otherwise a dashboard of nothing.
- **Local LLM inference** — on the 13" with no dGPU, an 8B model on CPU runs at a
  few tokens/sec. Not worth it. Reconsider only if `inventory.sh` finds a 1050 Ti.
- **Kubernetes / k3s** — no. One node, one admin, no scaling problem. Overhead
  shaped like a solution.
- **A public web host.** Tailscale Funnel exists and works, but anything expected
  to be up while this laptop isn't belongs on something rented.

---

## OpenClaw

Its own section rather than a bullet in Tier 2, because its isolation
requirements are a constraint on the whole machine, not a detail of one service.

**What it is:** a self-hosted agent runtime and message router — a long-running
Node service connecting chat platforms (WhatsApp, Telegram, Signal, Discord,
Slack, Matrix, iMessage) to an agent that reads and writes files, runs shell
commands, browses the web and calls APIs. Independent foundation, no paid tier,
no telemetry beyond a version check you can disable.

**Why it belongs on this machine and not a laptop:** it's reachable from a phone
through a chat app that's already open, and it can *start* things rather than
waiting for a terminal. An agent that only answers when a laptop is open isn't an
assistant. Resource cost is a rounding error next to Immich — **1 vCPU / 1 GB
minimum**, 2 GB+ under Docker, Node 24.16+/26.1+.

### What it's for

Three modes, and the value is concentrated in the first:

- **Ask it from anywhere.** Capture to the Obsidian vault by message or voice
  note — the thing that currently needs a laptop and a terminal. Query the vault
  ("what did I write about X"). Server ops in words ("is the backup green", "why
  is the fan audible", "restart Jellyfin"). Library chores ("grab this link into
  Jellyfin", "find the photos from that trip").
- **It tells you, unprompted.** A morning digest *with judgment* — "this is the
  third night btrbk skipped because the disk wasn't mounted" is a sentence a
  timer can't write. Watchdogs where the interesting part is the interpretation.
- **It works while you're out.** Fire-and-forget repo chores ("bump the flake,
  build it, tell me if it breaks"), overnight transcription, OCR into Paperless.

Division of labour worth keeping straight: **ntfy for alerts, OpenClaw for the
ones where you want to ask a follow-up.** And Claude Code stays the tool for work
you watch and steer; OpenClaw is for work thrown over the wall from a phone.

**Two to stay away from.** Work systems (Shortcut, Clockify, the wiki): work
credentials in cleartext on a personal box, reachable by an agent that takes
instructions from chat messages, is a policy question before a technical one.
And anything where a wrong action is expensive — it has host shell access.

### Why it's installed imperatively

OpenClaw self-updates, installs skills at runtime from ClawHub, and writes into
its own state directory. That's a direct fight with an immutable store, which is
why the Nix packaging has rough edges and the official docs' Nix page is Home
Manager-shaped rather than a proper NixOS service. There are several competing
community flakes; **check the current state rather than trusting a module name.**

So the line is drawn at *who owns supervision and the security boundary*, not at
who owns the bytes:

- **Nix declares** the dedicated user, the state directory, the systemd unit, and
  the hardening: `NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, an
  explicit `ReadWritePaths` allowlist, and the firewall keeping the gateway on
  `tailscale0`.
- **npm owns** the install, updated on its own schedule.

Prebuilt Node and native npm modules need a dynamic loader on NixOS —
`programs.nix-ld.enable`. (`nix/modules/nix-daemon.nix` already does this for
nvm's Node tarballs and bob's Neovim builds, so it's a trodden path.)

### The four security facts

1. **The gateway binds HTTP/WebSocket, and `0.0.0.0` exposes it to anyone who
   finds the IP.** Bind to loopback or the tailnet address; `openFirewall =
   false` plus `trustedInterfaces = [ "tailscale0" ]`. Never a port forward.
2. **The `exec` tool runs on the host** — not in a container, not as a sandboxed
   user. Tools flagged *elevated* run on the host even when the agent is
   otherwise sandboxed, by design. Snyk Labs documented a real bypass where the
   authenticated `/tools/invoke` endpoint didn't apply sandbox tool policies, so
   the boundary looked configured and wasn't enforced.
3. **The firewall does not protect the prompt surface.** OpenClaw connects
   *outbound* to WhatsApp and Telegram, so messages from arbitrary people reach
   the agent no matter how tight the tailnet is. Tailscale protects the control
   plane; it does nothing about a prompt injection arriving in a group chat, or a
   malicious ClawHub skill. That has been the actual incident pattern.
4. **The disk is unencrypted** (decided above), so its credential store — model
   API keys, WhatsApp session, chat tokens — is in cleartext on that NVMe.

**Therefore: do not co-locate it with Vaultwarden, the backup repo, or Immich's
library.** An agent with host shell access sharing a filesystem with the password
vault and the only copy of the photos is one prompt injection from a bad
afternoon. Either a dedicated hardened user with a tool allowlist, or a container
— noting the catch: **containerising it sandboxes `exec`, which also means it
can't restart Jellyfin or write to the vault unless those are mounted in. The
container's mounts become the tool policy.** That's a feature when the mounts are
chosen deliberately.

Every high-value use above is a *write* — to the vault, the library, service
control. Choose those write surfaces explicitly; read-only everywhere else costs
nothing and removes most of the bad afternoons.

**Sources** (fast-moving project — re-check at build time): `docs.openclaw.ai`,
its `/gateway/security` and `/gateway/sandboxing` pages, and Snyk Labs'
"Escaping the Agent" write-up on the sandbox bypass.

---

## Order of work

**The rule that orders everything: nothing gets a service until its data is in
the backup path.** Otherwise the machine built to hold things becomes the only
copy of them.

| Phase | Work | Done when |
|---|---|---|
| **0** | Run `inventory.sh`. Inspect the battery physically. Check BIOS for power-on-after-AC-loss. Buy a USB3 GbE adapter. Pick a hostname. | The hardware table has an "Actual" column |
| **1** | Minimal NixOS — **the step-by-step is `INSTALL.md`**: `server/flake.nix` + one host, plain btrfs via disko, sshd on tailscale0, `tailscale up` by hand, sleep + lid switch off | `ssh <name>` works from the phone on mobile data, and the machine returns from an unplug on its own |
| **2** | External disk, snapper + btrbk, restic to somewhere offsite | **A restore has been performed** |
| **3** | One data service — Syncthing, native NixOS module — and use it for a few weeks | It's been backed up and restored once |
| **4** | The container layer: Podman + `virtualisation.oci-containers`, first image (Immich or Jellyfin), pinned tags | A container survives a reboot and an image bump is a one-line diff |
| **5** | ntfy, exit node, node_exporter, and the rest, one at a time | Each added on its own, not in a batch |
| **6** | OpenClaw: hardened unit + imperative install, gateway on `tailscale0`, write surfaces chosen explicitly | It can write to the vault and nothing else, and you'd be relaxed about a stranger messaging it |

Then write it up properly: `docs/<symptom-shaped-title>.md` plus an `agents.md`
entry, per `CLAUDE.md`. This file is the plan; that's the record of what was done.

---

## Open questions

- **Hostname.** Needs one.
- **13" or 15"?** Decides the dGPU question, and so the LLM one.
- **8 or 16 GB?** Decides how much of Tier 1–2 can coexist. Soldered.
- **Does the BIOS have "power on after AC loss"?** If not, a long outage leaves
  the machine off until someone presses the button — which caps how much anything
  should depend on it.
- **Where does the offsite copy live?** B2, Borgbase, a drive elsewhere. Phase 2
  is only half-done without an answer.
- **Podman or Docker?** Podman is the better fit — rootless, no daemon, and
  `virtualisation.oci-containers.backend = "podman"` is well-trodden on NixOS.
  Take Docker only if something specifically needs compose features or a socket.
- **Stable or unstable nixpkgs?** Recommended stable, for the reasons under
  "Rebuilding it"; note that this is the opposite of what `nix/flake.nix` chose,
  deliberately — that machine is new hardware, this one is seven years old.

## Dead ends — don't re-derive these

- **Disk encryption.** Decided against; see above. Nothing to unlock, so no
  initrd network, no TPM2 enrolment, no dropbear.
- **Wifi as the only link.** It drops transfers mid-stream and the failure looks
  like corruption.
- **Tailscale SSH as the sole access path.** A broken `tailscaled` takes it with
  it. Keep a real sshd.
- **Importing `nix/modules/`.** Different machine, different shape, and that tree
  has never been built. Read it, copy from it, don't depend on it.
- **`:latest` image tags.** That's how a reboot silently becomes an upgrade, and
  how "it worked yesterday" stops being checkable. Pin, and bump on purpose.
- **Containerising OpenClaw and expecting it to still drive the host.** The
  container's mounts *are* its tool policy; sandboxing `exec` is exactly what
  stops it restarting services or writing to the vault.
- **Suspend "just for the night".** There is no such thing as a server that
  sleeps; disable the targets outright rather than trusting `logind` alone.
