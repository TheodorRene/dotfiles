# OpenClaw: a chat-driven agent (Telegram -> model -> tools on this host).
# Decided 2026-11-07: its own unprivileged user, Telegram, ChatGPT login.
#
# Split of ownership (README.md, "OpenClaw"):
#   Nix owns   the user, the unit, the sandbox, and Node itself.
#   npm owns   the openclaw package, installed into /var/lib/openclaw/.npm-global
#              by hand, because OpenClaw updates itself and installs plugins at
#              runtime, and nixpkgs' copy (2026.5.7) was six months stale.
#
# `openclaw-as <cmd…>` (below) runs a command as the openclaw user with this
# Node and npm prefix. Install / update, then (re)start:
#   openclaw-as npm i -g openclaw@latest --allow-scripts=openclaw
#   sudo systemctl restart openclaw-gateway
# The unit only starts once ${prefix}/bin/openclaw exists.
#
# State, credentials and config live in /var/lib/openclaw/.openclaw/ and are NOT
# in git: openclaw.json (Telegram bot token, gateway token), the SQLite auth
# store (the ChatGPT login). Losing the disk means redoing both logins.
{ config, lib, pkgs, ... }:

let
  home = "/var/lib/openclaw";
  prefix = "${home}/.npm-global";
  node = pkgs.nodejs_26; # OpenClaw wants Node 26 (or >= 24.22.1)
in
{
  users.groups.openclaw = { };
  users.users.openclaw = {
    isSystemUser = true;
    group = "openclaw";
    home = home;
    createHome = true;
    # A login shell so `sudo -u openclaw -H …` works for setup; no password,
    # no SSH key, not in wheel. Nothing can log in as it.
    shell = pkgs.bashInteractive;
  };

  # Prebuilt native npm modules expect a normal dynamic loader.
  programs.nix-ld.enable = true;

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "openclaw-as" ''
      exec sudo -u openclaw -H env \
        HOME=${home} NPM_CONFIG_PREFIX=${prefix} OPENCLAW_NO_RESPAWN=1 \
        PATH=${prefix}/bin:${node}/bin:${pkgs.e2fsprogs}/bin:/run/current-system/sw/bin \
        "$@"
    '')
  ];

  systemd.services.openclaw-gateway = {
    description = "OpenClaw gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Don't crash-loop before the npm install has happened.
    unitConfig.ConditionPathExists = "${prefix}/bin/openclaw";

    # What the agent's `exec` tool finds on PATH. Deliberately small; add tools
    # here when it needs them, rather than giving it the system profile.
    path = (with pkgs; [
      bashInteractive coreutils findutils gnugrep gnused gawk diffutils
      git curl jq ripgrep procps which gnutar gzip
      e2fsprogs # chattr: OpenClaw turns off btrfs CoW for its SQLite files
    ]) ++ [ node ];

    environment = {
      HOME = home;
      NPM_CONFIG_PREFIX = prefix;
      # systemd supervises it; don't let it respawn itself (docs.openclaw.ai/vps).
      OPENCLAW_NO_RESPAWN = "1";
      NODE_COMPILE_CACHE = "${home}/.cache/node-compile-cache";
    };

    serviceConfig = {
      User = "openclaw";
      Group = "openclaw";
      WorkingDirectory = home;
      # Loopback only (gateway.bind = "loopback" in openclaw.json); reach the
      # Control UI with `ssh -L 18789:127.0.0.1:18789 maman`.
      ExecStart = "${prefix}/bin/openclaw gateway --port 18789";
      Restart = "always";
      RestartSec = 5;
      # From the docs' sample unit: it drains sessions on stop.
      KillMode = "mixed";
      TimeoutStopSec = 330;

      # --- The sandbox -----------------------------------------------------
      # Everything the agent runs inherits this. It can write to its own home
      # and nowhere else; it can't become root; it can't see /home.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ home ];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
      SystemCallArchitectures = "native";
      # systemd's recommended service allowlist, minus privileged and
      # resource-control calls. EPERM rather than SIGSYS: a blocked call fails
      # like any other permission error instead of killing the agent's process.
      # Tested 2026-11-11 in a transient unit: node (child_process, workers),
      # git, tar, cp -p, curl, ps, free all fine; only `nice` is refused.
      # + mincore: not in @system-service, and without it the gateway logs
      # "database page-cache warm failed … access-denied: Operation not
      # permitted" at startup (its SQLite page-cache residency check). Found
      # with SystemCallLog=~@system-service: syscall 27, the only one outside.
      SystemCallFilter = [ "@system-service mincore" "~@privileged @resources" ];
      SystemCallErrorNumber = "EPERM";
      # Its /proc shows only its own processes (not trc's command lines).
      # NOT ProcSubset = "pid": that hides /proc/stat and /proc/meminfo, which
      # breaks Node's os.cpus() and the agent's free/uptime/top.
      ProtectProc = "invisible";
      # Own user namespace: every uid but root and openclaw shows as nobody.
      PrivateUsers = true;
      RemoveIPC = true;

      # --- No reaching into the home network or the tailnet ------------------
      # Decided 2026-11-07: the agent must not be able to connect to the XPS
      # (192.168.0.202 / 100.97.135.11) or anything else at home. Enforced by
      # the kernel (cgroup BPF) for every process in this unit, i.e. for every
      # command the agent runs. The public internet stays reachable (the model
      # API needs it). Allow beats Deny for the more specific entries below.
      IPAddressDeny = [
        "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16"   # LANs
        "100.64.0.0/10" "fd7a:115c:a1e0::/48"           # the tailnet
        "169.254.0.0/16" "fe80::/10" "fc00::/7"         # link-local, ULA
      ];
      IPAddressAllow = [
        "localhost"                                     # its own gateway; Serve
        "100.100.100.100" "fd7a:115c:a1e0::53"          # Tailscale DNS (resolv.conf)
      ];
      UMask = "0077";
      # NOT MemoryDenyWriteExecute: Node's JIT needs W+X pages.

      # 8 GB box: keep a runaway agent from taking the machine with it. The
      # gateway alone sat at ~1.6 GB of heap when idle (2026-11-07) and hit a
      # 2G cap, so: reclaim pressure above 2.5G, hard kill at 3.5G.
      MemoryHigh = "2560M";
      MemoryMax = "3584M";
      TasksMax = 512;
    };
  };

  # --- Reaching it: Tailscale Serve, run by root -----------------------------
  # https://maman.tailce1bce.ts.net -> 127.0.0.1:18789, tailnet only (not
  # Funnel). Root does this rather than OpenClaw's own gateway.tailscale.mode,
  # which would need the sandboxed user to be a Tailscale operator.
  # (services.tailscale.serve is for Tailscale *Services* (svc:), a different
  # feature.) Needs HTTPS certificates enabled for the tailnet (admin console,
  # DNS page); `tailscale serve` waits for that.
  systemd.services.tailscale-serve-openclaw = {
    description = "Tailscale Serve for the OpenClaw gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Without HTTPS enabled it waits for an admin to click; don't let that
      # hang a deploy. Retry every minute until it works.
      TimeoutStartSec = 30;
      Restart = "on-failure";
      RestartSec = 60;
      ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 http://127.0.0.1:18789";
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=443 off";
    };
  };
}
