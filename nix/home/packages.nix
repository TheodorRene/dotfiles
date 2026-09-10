# Per-user tooling. Everything here used to be installed by nvm / npm -g / bob /
# curl|bash on Ubuntu (REINSTALL.md §3.4–3.5); pulling it into the user profile
# means it's pinned by flake.lock and rolls back with the rest of the config.
{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # --- Node ---------------------------------------------------------------
    # nvm's Node tarballs are prebuilt glibc binaries; they only run on NixOS
    # via nix-ld (enabled in ../modules/nix-daemon.nix), and nvm stays useful for
    # projects pinning odd versions. But the *default* Node should come from
    # nixpkgs. zsh/.zshrc still sources ~/.nvm/nvm.sh when present, so both work:
    # nvm just wins on PATH once you `nvm use`.
    nodejs_22
    pnpm
    bun

    # --- Language servers / editor tooling ----------------------------------
    # The `npm install -g` list from REINSTALL.md §3.5, as packages.
    typescript
    typescript-language-server
    vscode-langservers-extracted # eslint, html, json, css
    tree-sitter # nvim-treesitter v1 needs the CLI to *compile* parsers, or
    # hover code blocks stay unstyled (nvim_v2/SETUP.md)
    lua-language-server
    nil # nix LSP — new, and worth having now that the config is Nix
    nixpkgs-fmt

    # nvim-treesitter compiles parsers with a C toolchain, and fff.nvim falls
    # back to `cargo build` if its prebuilt binary download fails.
    gcc
    gnumake
    cargo
    rustc

    opencode # the opencode/ config dir in this repo drives this
    claude-code # see docs/ubuntu-to-nixos.md — self-update vs. the store

    # --- direnv / nix ------------------------------------------------------
    direnv
    # direnv/direnvrc in this repo sources
    # $HOME/.nix-profile/share/nix-direnv/direnvrc and degrades gracefully if
    # it's absent — installing the package into the user profile is exactly what
    # that path expects, so nothing in the dotfiles changes.
    nix-direnv
  ];

  # NOTE: home-manager's programs.direnv.enable is intentionally NOT used. It
  # writes ~/.config/direnv/direnv.toml, which would collide with the whole-dir
  # symlink of direnv/ in ./dotfiles.nix — and that file has a hard-won comment
  # in it about log_filter being the only thing that silences direnv here.
}
