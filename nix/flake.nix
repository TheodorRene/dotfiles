{
  description = "trc's NixOS configs — Sway/Wayland, LUKS + btrfs, dual-boot";

  inputs = {
    # Unstable, deliberately: these are recent Intel laptops (Panther Lake on
    # `disco` still needs a mesa force-probe), so a stable channel's kernel and
    # mesa are likely too old. Pin to "nixos-26.05" once the hardware is boring.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative partitioning: the disk layout is Nix, and `disko` applies it.
    # Used by hosts/newhost; `disco` was installed by hand and keeps its
    # hand-written fileSystems block.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, disko, ... }:
    let
      # One place to add a machine. modules/ is host-agnostic; everything
      # machine-specific lives in hosts/<name>/.
      mkHost = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit nixos-hardware disko; };
        modules = [
          home-manager.nixosModules.home-manager
          ./hosts/${name}
        ];
      };
    in
    {
      nixosConfigurations = {
        # The new machine. Rename this and hosts/newhost/ to its real hostname —
        # see README.md, "Adding the new machine".
        newhost = mkHost "newhost";

        # This laptop (Dell XPS 14, Panther Lake), kept as the worked example the
        # rest was derived from.
        disco = mkHost "disco";
      };

      devShells.x86_64-linux.default =
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in pkgs.mkShell {
          packages = [
            pkgs.nixpkgs-fmt
            pkgs.nil
            disko.packages.x86_64-linux.disko
          ];
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
