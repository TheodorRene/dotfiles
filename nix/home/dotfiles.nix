# The dotfile links — the declarative replacement for symlinkifier.pl.
#
# Deliberately *out-of-store* symlinks (mkOutOfStoreSymlink): each target points
# at ~/dotfiles/<path>, not at a copy in /nix/store. That keeps the workflow this
# repo is built around — edit sway/config, `swaymsg reload`, done; no rebuild, no
# `git add` to make the change visible. The tradeoff is that these links are only
# valid while ~/dotfiles exists, so clone the repo *before* the first
# `nixos-rebuild switch` (see ../README.md).
#
# The lists below mirror symlinkifier.pl one-for-one. When you add a config
# there, add it here (or vice versa — both scripts can coexist; running
# symlinkifier.pl on NixOS still works, it just fights home-manager for the same
# paths).
{ config, lib, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # symlinkifier.pl: "Config directories under ~/.config"
  configDirs = [
    "i3"
    "sway"
    "kanshi"
    "waybar"
    "wofi"
    "xdg-desktop-portal"
    "swaylock"
    "alacritty"
    "kitty"
    "mako"
    "opencode"
    "direnv"
  ];

  # symlinkifier.pl: "Config that resides in the home folder"
  homeFiles = [
    ".tmux.conf"
    ".vimrc"
    ".zshrc"
    ".gitconfig"
  ];
in
{
  home.file = lib.mkMerge [
    (lib.genAttrs homeFiles (f: { source = link f; }))

    (lib.listToAttrs (map
      (d: lib.nameValuePair ".config/${d}" { source = link d; })
      configDirs))

    {
      # Neovim v2 config lives under a different name in the repo.
      ".config/nvim".source = link "nvim_v2";

      # Claude Code: individual files only, never the whole ~/.claude — the rest
      # of that directory (memory, projects, plans, history) is state, not
      # config, and must not be replaced by a link into the repo. See CLAUDE.md.
      ".claude/settings.json".source = link "claude/settings.json";
      ".claude/statusline-command.sh".source = link "claude/statusline-command.sh";
      # Whole dir, so any skill dropped into the repo shows up.
      ".claude/skills".source = link "claude/skills";
    }
  ];

  # NOT linked, on purpose:
  #   - ~/.config/Code/User/settings.json — symlinkifier.pl has it commented out
  #     because it breaks when VS Code isn't installed.
  #   - anything under ~/.claude beyond the three paths above (state).
  #   - ~/wallpapers — restored from backup (REINSTALL.md §3.6); swaybg and the
  #     $lock command in sway/config both read it, and both fail silently if it's
  #     missing.
}
