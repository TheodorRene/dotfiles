#!/usr/bin/env bash
# Waybar custom module: reflect Claude Code state written by the hooks.
# State lives in $XDG_RUNTIME_DIR/claude-waybar-state (working|waiting|idle).
state_file="${XDG_RUNTIME_DIR:-/tmp}/claude-waybar-state"
state="$(cat "$state_file" 2>/dev/null || echo idle)"

case "$state" in
  working) printf '{"text":"🤖","class":"working","tooltip":"Claude is working"}\n' ;;
  waiting) printf '{"text":"🤖 needs input","class":"waiting","tooltip":"Claude needs your input — click to focus"}\n' ;;
  *)       printf '{"text":"","class":"idle","tooltip":"Claude idle"}\n' ;;
esac
