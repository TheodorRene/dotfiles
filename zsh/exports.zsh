
export NVM_DIR="$HOME/.nvm"

export XDG_CONFIG_HOME=$HOME/.config

NPM_PACKAGES="${HOME}/.npm-packages"

# Preserve MANPATH if you already defined it somewhere in your config.
# Otherwise, fall back to `manpath` so we can inherit from `/etc/manpath`.
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

export MANPAGER='nvim +Man!'


export EDITOR=$(which nvim)
export VISUAL=$(which nvim)

# Wayland / Sway
export MOZ_ENABLE_WAYLAND=1
export XDG_CURRENT_DESKTOP=sway
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export INTEL_FORCE_PROBE=b080
export GTK_USE_PORTAL=0
