# Wire home-manager in as a NixOS module, so `nixos-rebuild switch` applies the
# system and the user config together (no separate `home-manager switch`).
{ config, lib, pkgs, ... }:

{
  home-manager = {
    # Use the system's nixpkgs + config (allowUnfree etc.) rather than a second
    # instance — halves evaluation time and avoids two nixpkgs in the closure.
    useGlobalPkgs = true;
    useUserPackages = true;

    # If home-manager finds an existing file where it wants to write one, it
    # moves it aside with this suffix instead of failing the whole activation.
    # Relevant on the first switch after a migration, when ~/.zshrc etc. already
    # exist as symlinks made by symlinkifier.pl.
    backupFileExtension = "hm-bak";

    users.trc = import ../home/trc.nix;
  };
}
