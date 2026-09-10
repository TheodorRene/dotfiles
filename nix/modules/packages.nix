# System-wide packages: the apt lists from REINSTALL.md §3.5, translated.
#
# Split rule of thumb: anything the *system* or a root-owned unit needs, or that
# should exist even in a rescue shell, goes here. Per-user tooling (language
# servers, node, neovim plugins' helpers) lives in ../home/packages.nix so it can
# change without a system rebuild.
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # --- shell + core ------------------------------------------------------
    git
    curl
    wget
    perl # symlinkifier.pl (kept working even though home/dotfiles.nix replaces it)
    zsh
    file
    tree
    unzip
    zip
    psmisc # killall, fuser — sway/config's `pkill waybar` uses procps' pkill
    lsof # `ports` alias
    socat
    rsync

    # --- CLI tools (apt "CLI tools" block) --------------------------------
    fzf
    ripgrep
    eza
    bat
    bfs # backs the `fd()` function in zsh/functions.zsh
    direnv
    htop
    btop
    tmux
    mosh
    just
    mpv
    autojump
    jq # every waybar custom module + claude-attention.sh parses JSON with it
    ncdu
    difftastic # .gitconfig's diff.external=difft
    gh
    vim
    neovim # see docs/ubuntu-to-nixos.md: replaces the `bob` version manager
    ruby # scripts/weekly-note.rb (the `week` function)
    python3
    translate-shell # `english2norsk` / `norsk2english` aliases
    bitwarden-cli # the `pass` function
    xclip # X11 clipboard, for the Xwayland-only aliases
    dnsutils # `dig` alias
    openssl # `gencert` alias
    ghostscript # the `minpdf` function

    # --- hardware / diagnostics -------------------------------------------
    pciutils
    usbutils
    lm_sensors
    powertop
    smartmontools # `smartctl -a /dev/nvme0n1` (needs root, as noted in CLAUDE.md)
    nvme-cli
    cryptsetup # systemd-cryptenroll for the TPM plan, luksDump for diagnostics
    e2fsprogs # tune2fs
    v4l-utils
    libva-utils # vainfo
    vulkan-tools
    mesa-demos # glxinfo, for checking whether INTEL_FORCE_PROBE is still needed
    intel-gpu-tools

    # --- desktop apps -----------------------------------------------------
    kitty
    alacritty
    networkmanagerapplet # nm-connection-editor, waybar's network on-click
    kooha # screen recording
    slack
    chromium
    feh # `setbackground` alias (X11-only; swaybg is what sway/config uses)

    # --- compat shims ------------------------------------------------------
    # Ubuntu renames bat's binary to `batcat` (name clash with the `bacula-tools`
    # package); nixpkgs ships it as `bat`. zsh/alias.zsh has `alias cat="batcat"`,
    # so without this every `cat` in an interactive shell breaks. Shimming here
    # keeps the dotfiles portable between the two machines instead of forking the
    # alias file.
    (writeShellScriptBin "batcat" ''exec ${pkgs.bat}/bin/bat "$@"'')
  ];

  # Ubuntu's `mem-report.sh` reads /proc and /sys only — no extra packages.

  # Kitty/alacritty are the terminals sway/config launches; both are listed so
  # `$mod+Return` (alacritty) and waybar's lazydocker click (kitty) both work.
}
