#!/bin/sh
# Claude Code status line — mirrors _build_prompt from ~/.zshrc

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')

# Shorten path: replace $HOME with ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch and dirty indicator (skip optional locks)
branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
git_part=''
if [ -n "$branch" ]; then
    dirty=''
    git -C "$cwd" diff --quiet 2>/dev/null || dirty='*'
    git -C "$cwd" diff --cached --quiet 2>/dev/null || dirty='*'
    git_part=$(printf ' \033[32m%s%s\033[0m' "$branch" "$dirty")
fi

# Nix shell indicator
nix_part=''
if [ -n "$IN_NIX_SHELL" ]; then
    nix_part=$(printf ' \033[33m[nix]\033[0m')
fi

# Model display name
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_part=''
if [ -n "$model_name" ]; then
    model_part=$(printf ' \033[35m%s\033[0m' "$model_name")
fi

printf '\033[34m%s\033[0m%s%s%s\n' "$short_cwd" "$git_part" "$nix_part" "$model_part"
