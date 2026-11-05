#!/usr/bin/env bash
# cargo-sweep-targets.sh — delete Rust build artifacts not used for DAYS days
# from the impero checkout (local `target`, Docker `target_docker`) and every
# worktree under ~/dev/worktrees. Incremental caches pile up on every branch
# switch and are never pruned by cargo itself.
#
# Usage: cargo-sweep-targets.sh [DAYS] [--dry-run]   # DAYS defaults to 14
set -uo pipefail

DAYS="${1:-14}"
shift || true
NIX=/nix/var/nix/profiles/default/bin/nix

for backend in "$HOME/dev/impero/backend" "$HOME"/dev/worktrees/*/backend; do
  [ -f "$backend/Cargo.toml" ] || continue
  for target in target target_docker; do
    [ -d "$backend/$target" ] || continue
    # cargo-sweep finds the dir through `cargo metadata`, which honours CARGO_TARGET_DIR
    CARGO_TARGET_DIR="$backend/$target" \
      "$NIX" shell nixpkgs#cargo-sweep nixpkgs#cargo \
      -c cargo-sweep sweep --time "$DAYS" "$@" "$backend"
  done
done
