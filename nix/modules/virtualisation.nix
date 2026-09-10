# Docker. The impero .NET backend, postgres, redis and azurite all run in
# `docker compose` (see CLAUDE.md), and waybar has a custom docker module
# (scripts/waybar-docker.sh) that shells out to `docker`.
{ config, lib, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    # compose v2 as a plugin, i.e. `docker compose` (not docker-compose) —
    # matches docker-compose-plugin on Ubuntu and every command in the impero
    # justfile.
    enableOnBoot = true;
  };

  # `docker compose` and `docker buildx` come from these; nixpkgs ships them as
  # CLI plugins rather than inside the docker package.
  environment.systemPackages = with pkgs; [
    docker-compose
    docker-buildx
    lazydocker # $mod-clicked from waybar; on Ubuntu this was a curl|bash install
  ];

  # Prune dangling images/build cache weekly. The nuke_* helpers in
  # zsh/functions.zsh exist because this used to be manual.
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--filter" "until=168h" ];
  };
}
