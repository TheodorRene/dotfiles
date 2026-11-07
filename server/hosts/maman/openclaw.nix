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
        PATH=${prefix}/bin:${node}/bin:/run/current-system/sw/bin \
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
      UMask = "0077";
      # NOT MemoryDenyWriteExecute: Node's JIT needs W+X pages.

      # 8 GB box: keep a runaway agent from taking the machine with it.
      MemoryMax = "2G";
      TasksMax = 512;
    };
  };
}
