# Environment

## OS & Desktop
- **OS**: Ubuntu 26.04 LTS
- **Display server**: Wayland
- **Compositor**: Sway (i3-compatible tiling WM)
- **Status bar**: Waybar
- **App launcher**: Wofi
- **Display config**: Kanshi (dynamic output management)
- **Desktop portal**: xdg-desktop-portal (Wayland variant)

## Terminal & Shell
- **Terminal**: Alacritty
- **Shell**: zsh (via oh-my-zsh)

## Editor
- **Primary**: Neovim (`$EDITOR` and `$VISUAL` both set to `nvim`)
- Man pages open in Neovim (`MANPAGER=nvim +Man!`)

## Runtimes & Package Managers
- **System packages**: apt
- **Node.js**: managed via nvm (lazy-loaded in zsh)
- **npm globals**: installed to `~/.npm-packages`

## Wayland-specific env
- `MOZ_ENABLE_WAYLAND=1` — Firefox runs native Wayland
- `XDG_CURRENT_DESKTOP=sway`
- `ELECTRON_OZONE_PLATFORM_HINT=wayland` — Electron apps use Wayland
- `GTK_USE_PORTAL=0`

# Conventions

## Git
- **Do not create branches for this project — commit directly to `main`.**
- **Never add Claude attribution to commits** (no `Co-Authored-By: Claude`
  trailer, no "Generated with Claude Code" lines).
