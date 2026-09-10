# The Nix daemon itself. Replaces the Determinate Nix install from
# REINSTALL.md §3.5 — on NixOS the daemon is part of the system.
{ config, lib, pkgs, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Needed so this user can add substituters / use `nix develop` with
    # per-project caches (impero's flake).
    trusted-users = [ "root" "trc" ];

    # 16 cores: let a build use them, but don't let one derivation hog all of
    # them while the desktop is interactive.
    max-jobs = 8;
    cores = 4;

    # Deduplicate the store as it's written — this machine builds a lot of
    # near-identical closures (rebuild-per-edit workflow).
    auto-optimise-store = true;

    keep-outputs = true;
    keep-derivations = true;
  };

  # Weekly GC of anything older than a month. Without this, /nix/store growth
  # on a 451 GB root that also holds ~/dev is a slow leak.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Prebuilt, non-Nix binaries need a dynamic loader. This machine has several:
  # nvm's Node tarballs, bob's neovim builds, the lazydocker install script,
  # fff.nvim's downloaded Rust binary, ~/.dotnet, bun. nix-ld makes them run
  # unpatched — see docs/ubuntu-to-nixos.md for which ones are better replaced
  # with nixpkgs versions instead.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
    curl
    libxml2
    icu # .NET
    libunwind # .NET
    krb5 # .NET
    glib
    util-linux
  ];

  nixpkgs.config.allowUnfree = true;
}
