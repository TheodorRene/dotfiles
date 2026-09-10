# Everything shared by all hosts. A host's default.nix imports this plus its own
# hardware + disk modules, and sets the handful of `local.*` knobs from
# ./options.nix.
{ ... }:

{
  imports = [
    ./options.nix
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./memory.nix
    ./nix-daemon.nix
    ./desktop.nix
    ./audio.nix
    ./bluetooth.nix
    ./security.nix
    ./services.nix
    ./virtualisation.nix
    ./backup.nix
    ./fonts.nix
    ./packages.nix
    ./users.nix
    ./home-manager.nix
  ];
}
