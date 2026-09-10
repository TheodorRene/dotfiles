# Networking. Hostname lives in hosts/disco/default.nix.
{ config, lib, pkgs, ... }:

{
  networking.networkmanager.enable = true;

  # Blocks boot ~5 s waiting for the network to be fully up; nothing in a Sway
  # session gates on it. Same change as scripts/install-perf-tuning.sh.
  systemd.services.NetworkManager-wait-online.enable = false;

  # /etc/hosts is generated on NixOS, so impero's `just add_hosts` (which appends
  # to /etc/hosts with sudo) can't work — it would be reverted on the next
  # rebuild anyway. Declare the block here instead; contents mirror
  # ~/dev/impero/tools/nix/hosts as of 2026-08-31. Re-check that file after
  # pulling impero, and run `just remove_hosts` once if the imperative block is
  # still present from the Ubuntu install.
  networking.hosts = {
    "127.0.0.1" = [
      # dev
      "global.localhost"
      "impero-dev.localhost"
      "login.localhost"
      "testfoss.localhost"
      "impero"
      "impero_log"
      "impero_cache"
      "azurite"
      # test
      "impero_db"
      "impero_test_db"
      "impero_test_cache"
      "localhost_2"
      "localhost_3"
    ];
  };

  # Laptop on untrusted networks: default-deny inbound. Nothing here listens on
  # purpose (no sshd — see docs/claude-code-from-phone.md if that changes).
  networking.firewall.enable = true;
}
