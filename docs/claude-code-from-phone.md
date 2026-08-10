# Driving Claude Code from a phone (SSH over Tailscale) — plan, not yet applied

**Status: nothing here is applied.** No SSH server is installed, no Tailscale,
and `claude-attention.sh` is unchanged. This is the write-up so it can be done
in one sitting later. Written 2026-08-06.

Goal: from a phone, attach to a long-running Claude Code session on the XPS —
with the real working tree, the `nix develop` shell and the docker compose
stack — fire off a task, lock the phone, and get pushed a notification when
Claude needs input or finishes.

## Starting state (verified 2026-08-06)

| Thing | State |
|---|---|
| `openssh-server` | **not installed** — hence no `/etc/ssh/sshd_config` |
| `ssh` / `sshd` / `tailscaled` units | all `inactive` |
| `mosh` | 1.4.0-1ubuntu5 installed (the package is client **and** server) |
| `tmux`, `screen` | both in `/usr/bin` |
| `zellij` | **not** on PATH — comes from the impero nix shell only |
| Network | `wlp0s20f3` = `192.168.1.60/24`, i.e. behind NAT, no public IP |
| Claude hooks | `Notification` + `Stop` → `scripts/claude-attention.sh`, sway/mako-only |

## Why Tailscale, and why it doesn't need paying for

WireGuard is the **data plane** — a small fast kernel VPN, encryption and
nothing else. Tailscale is a **control plane on top of WireGuard** (it embeds
wireguard-go). Everything WireGuard leaves to you, Tailscale automates:

| | Raw WireGuard | Tailscale |
|---|---|---|
| Key distribution | Hand-edit configs on both ends | Automatic per-device, rotated |
| Reaching a NAT'd laptop | Needs a public IP or a rented VPS relay | NAT hole-punching, DERP relay fallback |
| Endpoint changes (wifi → 5G) | Breaks until reconfigured | Handled |
| Adding a device | Edit N configs | Log in on the device |
| Naming | Remember `100.x.y.z` | MagicDNS: `ssh xps` |

The part worth paying for isn't the crypto, it's **coordination and NAT
traversal** — this machine has no public IP, so without a rendezvous service a
phone on mobile data cannot find it. The plain-WireGuard answer to that is
renting a VPS with a public IP as a hub, which costs real money and admin time.

**The free tier covers this case**: 100 devices, 3 users, personal use. Paid
plans are for teams/SSO/ACL policy. Tailscale never sees traffic contents (keys
stay on devices, end-to-end encrypted) but does see the device list and
connection metadata.

If handing coordination to a third party is unacceptable: **Headscale** is an
open-source reimplementation of the control server, and the official clients
speak to it. It still needs a public-IP box, so it trades money-and-trust for
money-and-maintenance.

**Do not** port-forward :22 on the router as a shortcut. That is precisely the
setup Tailscale exists to avoid.

## Step 1 — SSH server (needs root, run manually)

`sudo` cannot be driven from Claude Code here (see `CLAUDE.md`), so these are
run by hand.

```sh
sudo apt install openssh-server
```

Ubuntu uses socket activation, so it starts listening on :22 immediately after
install — **harden before it is reachable from anywhere**. Ubuntu ships
`Include /etc/ssh/sshd_config.d/*.conf` at the top of `sshd_config`, so a
drop-in is the right shape (and keeps the package config pristine):

`etc/ssh/sshd_config.d/99-local.conf` in this repo:

```
# Key-only auth. Passwords are the whole attack surface of an exposed sshd.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no

# Only listen on the tailnet + loopback once Tailscale is up (see note below).
#ListenAddress 100.x.y.z
#ListenAddress 127.0.0.1
```

Then:

```sh
sudo systemctl restart ssh.socket ssh.service
```

On `ListenAddress`: pinning sshd to the tailnet IP is the strongest version of
this, but it makes sshd fail to start if `tailscaled` hasn't brought the
interface up yet, and it locks out LAN access. Left commented — decide after
Tailscale is running. A simpler equivalent is `sudo ufw allow in on tailscale0
to any port 22` and no blanket allow.

### Repo wiring

Mirror the `install-oomd-tuning.sh` pattern — system configs live under `etc/`
and are symlinked into `/etc/` by an installer in `scripts/`, **not** by
`symlinkifier.pl`:

- `etc/ssh/sshd_config.d/99-local.conf` — as above
- `scripts/install-ssh-server.sh` — `set -euo pipefail`, check the source file
  exists, `sudo mkdir -p /etc/ssh/sshd_config.d`, `sudo ln -sfn`, restart, then
  echo back the verification (`sshd -T | grep -E 'passwordauthentication|permitrootlogin'`).

### Keys

Generate the keypair **on the phone** in the SSH client, and paste its public
key into `~/.ssh/authorized_keys` here. Never move a private key onto a phone.
(Or skip this entirely — see Tailscale SSH below.)

## Step 2 — Tailscale (needs root, run manually)

```sh
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Then install the Tailscale app on the phone and log in with the same identity.
The machine becomes reachable as `xps` (MagicDNS) from any device on the
tailnet, wherever either one is.

`--ssh` is worth taking: `tailscaled` then terminates SSH itself and authorises
against tailnet identity, so **no keypair on the phone at all** and no
`authorized_keys` management. Connections are still `ssh trc@xps`. Downside is
that SSH auth now depends on the Tailscale control plane being reachable —
keeping openssh-server installed and key-auth-capable is the fallback, which is
why Step 1 is still worth doing.

Useful afterwards:

- `tailscale status` — who's on the tailnet, and whether the link is direct or
  relayed via DERP.
- `tailscale netcheck` — NAT/UDP diagnosis when a connection insists on relaying.

## Step 3 — Persistent session (the non-negotiable bit)

Mobile links drop. If `claude` is a child of the SSH session, a drop kills it
mid-edit. Always attach through a multiplexer:

```sh
ssh xps -t 'tmux new -A -s claude'
```

`new -A` attaches if the session exists and creates it otherwise — one
idempotent command, safe to save as the phone client's startup command.

Use **tmux, not zellij**, for the outer session: zellij only exists inside the
impero nix shell, tmux is at `/usr/bin/tmux` and there's already a
`.tmux.conf` in this repo (mouse mode on, which is genuinely useful for
touch-scrolling). Running zellij *inside* tmux for the impero panes is fine.

Add mosh on top so switching wifi→5G, or locking the phone for an hour, doesn't
even interrupt the session:

```sh
ssh xps            # first, so mosh isn't the only path in
mosh xps -- tmux new -A -s claude
```

The `mosh` package is already installed and provides `mosh-server` too, so
nothing to install. Note mosh needs UDP 60000-61000; over Tailscale that's
inside the tunnel and needs no firewall work.

## Step 4 — Push notifications (the actual unlock)

Watching a TUI on a phone is miserable. The workflow that works is: send a
task, lock the phone, get pinged. The two moments worth a ping are exactly the
two hooks already wired in `claude/settings.json`:

- `Notification` → Claude needs input (permission prompt, question)
- `Stop` → Claude finished

`scripts/claude-attention.sh` handles both, but everything it does is
sway-local: `swaymsg urgent enable`, a clickable `notify-send` toast, and
`swaymsg focus` on click. From a phone that is all wasted.

### Design

[ntfy.sh](https://ntfy.sh) is the low-friction option: no account, install the
app, subscribe to an unguessable topic name, and an HTTP POST becomes a push
notification. The topic name **is** the credential, so use something long and
random and keep it out of the repo.

The script already computes whether it can find its own sway container via
`find_con()`. That's the natural branch point, but note it is **not** a reliable
"am I at the machine" test — a tmux session started over SSH has no sway
container even when you're sitting in front of the laptop. Cheapest honest
signal is `[ -n "$SSH_CONNECTION" ]`, evaluated in the `claude` process's
environment. Simplest robust answer: **do both** — desktop toast when a sway
container is found, and always also push, gated on the topic env var being set.

```sh
# in claude-attention.sh, alongside the existing notify-send calls
ntfy_push() {
  local title="$1" body="$2" prio="${3:-default}"
  [ -n "${NTFY_TOPIC:-}" ] || return 0
  curl -fsS --max-time 5 \
    -H "Title: $title" -H "Priority: $prio" -H "Tags: robot" \
    -d "$body" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
}
```

Called as `ntfy_push "Claude Code" "$msg" high` in the `waiting` branch and
`ntfy_push "Claude Code" "Done — finished working"` in `idle`.

Points to get right:

- `--max-time 5` and `|| true` — a hook that blocks or fails must never wedge
  Claude Code.
- Do the push **before** the existing `setsid -f` toast branch in `waiting`,
  since that path forks and re-execs the script.
- `NTFY_TOPIC` goes in a gitignored file (`zsh/local.zsh` or similar) exported
  from the shell that launches `claude`. **Not** in this repo.
- Priority `high` on `waiting` (it's blocking), default on `idle`.

Self-hosting ntfy later is possible and would remove the third party, but it
needs a public endpoint — same tradeoff as Headscale, and not worth it for
"Claude wants a yes/no".

## Step 5 — Permission prompts

Every prompt is a tap on a phone keyboard, with much less context visible than
on the desktop. Two mitigations, in order of preference:

1. Build out `permissions.allow` in `claude/settings.json`. The
   `/fewer-permission-prompts` skill scans past transcripts and generates a
   prioritised allowlist — run it before the first real phone session.
2. Launch phone sessions with `--permission-mode acceptEdits` so file edits go
   through and only shell commands prompt.

`--dangerously-skip-permissions` is the wrong trade for a session supervised
through a 6-inch window on a machine with real work on it.

## Step 6 — Phone client

Blink (iOS) or Termux (Android) — both speak mosh and both have a usable
ctrl/esc/arrow row. Termius is the friendlier cross-platform option but its
mosh support is weaker.

- Landscape is much better than portrait; the TUI reflows fine but 80 columns
  matters.
- Shift+Enter for multiline input won't reach the terminal on most phone
  clients. `\` then Enter works.
- `.tmux.conf` already has `set -g mouse on`, so touch-drag scrolls scrollback.

## The lid problem

All of the above assumes the machine is **awake**. A suspended XPS drops off
the tailnet entirely and there is no waking it remotely — Wake-on-LAN can't
help because the tailnet is down while asleep, and WoL over wifi is unreliable
regardless.

So if this becomes a real workflow, suspend-on-lid-close has to go while on AC:

```
# /etc/systemd/logind.conf.d/10-no-suspend-on-ac.conf
[Login]
HandleLidSwitchExternalPower=ignore
```

`HandleLidSwitchExternalPower` (not `HandleLidSwitch`) keeps battery behaviour
untouched — closing the lid unplugged still suspends. Would live at
`etc/systemd/logind.conf.d/` in this repo and be installed by the same
`install-ssh-server.sh`, or its own script. Note the screen still locks via
swayidle; that's independent and fine.

## Not chosen, and why

| Option | Why not |
|---|---|
| Port-forward :22 on the router | Exposes sshd to the internet; the thing Tailscale replaces |
| Raw WireGuard + rented VPS | Costs money and admin time to replicate NAT traversal |
| Headscale | Same public-IP requirement as the VPS, plus maintenance |
| `claude.ai/code` (web) | Cloud sandbox — no local working tree, no `nix develop`, no docker compose. Fine for throwaway questions against a GitHub repo, not for impero work |
| zellij as the outer multiplexer | Not on PATH outside the nix shell |
| `--dangerously-skip-permissions` | Unsupervised writes on the real machine |

## Order of operations

1. `sudo apt install openssh-server` + the `99-local.conf` drop-in, restart, verify with `sshd -T`.
2. Install Tailscale, `sudo tailscale up --ssh`, install the phone app, confirm `ssh xps` works from the phone on **mobile data** (not just home wifi — that's the case that proves NAT traversal).
3. `ssh xps -t 'tmux new -A -s claude'`, confirm detach/reattach survives killing the connection.
4. ntfy: install the app, pick a topic, export `NTFY_TOPIC`, patch `claude-attention.sh`, test with a deliberate permission prompt.
5. `/fewer-permission-prompts` to trim the prompt volume.
6. Decide on the logind lid drop-in.
7. Optionally pin sshd to the tailnet (`ListenAddress` or ufw).
