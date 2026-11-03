#!/usr/bin/env bash
# One set of Alt keys for nvim windows and herdr panes (vim-tmux-navigator style).
# Bound by [[keys.command]] entries in herdr/config.toml.
#
#   herdr-nav.sh <key> focus left|right|up|down
#   herdr-nav.sh <key> split right|down
#   herdr-nav.sh <key> tab prev|next
#
# If the pane the key was pressed in is running nvim, <key> is forwarded to it
# unchanged, and nvim's own mapping handles it. Its <A-hjkl> continue into the
# neighbouring herdr pane at the edge (nvim_v2/lua/config/keymaps.lua). Anywhere
# else the herdr action runs directly.
set -euo pipefail

key=$1 action=$2 arg=$3
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_ACTIVE_PANE_ID:?not run from a herdr key command}

if "$herdr" pane process-info --pane "$pane" \
    | jq -e '.result.process_info.foreground_processes[] | select(.name == "nvim")' >/dev/null; then
    exec "$herdr" pane send-keys "$pane" "$key"
fi

case $action in
focus)
    exec "$herdr" pane focus --pane "$pane" --direction "$arg"
    ;;
split)
    exec "$herdr" pane split --pane "$pane" --direction "$arg" \
        --cwd "${HERDR_ACTIVE_PANE_CWD:-$HOME}" --focus
    ;;
tab)
    # No "next tab" in the CLI: step through the workspace's tabs (listed in
    # display order) from the current one, wrapping at both ends.
    mapfile -t tabs < <("$herdr" tab list --workspace "${HERDR_ACTIVE_WORKSPACE_ID:?}" \
        | jq -r '.result.tabs[].tab_id')
    for i in "${!tabs[@]}"; do
        [[ ${tabs[i]} == "${HERDR_ACTIVE_TAB_ID:?}" ]] || continue
        step=1; [[ $arg == prev ]] && step=-1
        exec "$herdr" tab focus "${tabs[(i + step + ${#tabs[@]}) % ${#tabs[@]}]}"
    done
    ;;
esac
