{
  description = "maman — home server (HP Spectre x360 13-ac0XX)";

  inputs = {
    # Stable, deliberately: the opposite of nix/flake.nix, and for the opposite
    # reason. This is 2016 hardware that needs nothing new from a kernel, and an
    # always-on box is the worst place for an unstable channel's breakage.
    # 26.05 is supported until the end of 2026; move to 26.11 once it's out.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
    # Renaming the host = renaming this attribute, hosts/<dir>, and
    # networking.hostName in hosts/<dir>/default.nix.
    nixosConfigurations.maman = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/maman
      ];
    };
  };
}
