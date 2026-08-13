#!/usr/bin/env bash
# Share ONE Claude Code memory directory across a project's subdirectories.
#
# Claude Code keys its memory dir to the literal cwd:
#   ~/.claude/projects/<slug>/memory   where slug = absolute path, / . _ -> -
# so opening Claude in ~/dev/impero/backend starts from an *empty* memory instead
# of the project's. This replaces each subdir's memory dir with a symlink to the
# project root's, so every one of them reads and writes the same set of files.
#
# (CLAUDE.md needs none of this — that one is already loaded from the cwd and
# every parent dir up to /. This is only about the memory tool.)
#
# Usage:
#   install-claude-memory-links.sh [PROJECT_ROOT] [SUBDIR ...]
#
#   PROJECT_ROOT  defaults to ~/dev/impero
#   SUBDIR        relative subdir(s) to link even if Claude was never opened
#                 there yet (e.g. tools docs). With none given, every subdir
#                 that already has a project dir is linked.
#
# Idempotent — re-running is a no-op. A subdir memory dir holding real files is
# left alone and reported, never silently discarded.
set -euo pipefail

PROJECTS="${CLAUDE_PROJECTS:-$HOME/.claude/projects}"
ROOT="${1:-$HOME/dev/impero}"
[[ $# -gt 0 ]] && shift
ROOT="${ROOT%/}"

[[ -d "$ROOT" ]] || { echo "no such project root: $ROOT" >&2; exit 1; }
mkdir -p "$PROJECTS"

# The slug Claude Code derives from a working directory.
slug() { printf '%s' "$1" | sed 's|[/._]|-|g'; }

ROOT_SLUG="$(slug "$ROOT")"
ROOT_MEM="$PROJECTS/$ROOT_SLUG/memory"
mkdir -p "$ROOT_MEM"
echo "shared memory: $ROOT_MEM"
echo

# Collect subdir paths to consider: the explicit args, else every real subdir
# (2 levels deep) that Claude has already been opened in. Deriving these from
# real directories on disk — rather than globbing "$ROOT_SLUG-*" — keeps sibling
# projects like ~/dev/impero-tools from being swept in, since a slug can't be
# reversed unambiguously.
targets=()
if [[ $# -gt 0 ]]; then
  for sub in "$@"; do targets+=("$ROOT/${sub%/}"); done
else
  while IFS= read -r d; do
    [[ -d "$PROJECTS/$(slug "$d")" ]] && targets+=("$d")
  done < <(find "$ROOT" -mindepth 1 -maxdepth 2 -type d \
             -not -path '*/.*' -not -path '*/node_modules*' -not -path '*/target/*' \
             2>/dev/null | sort)
fi

[[ ${#targets[@]} -gt 0 ]] || { echo "nothing to link (no subdir project dirs found)"; exit 0; }

linked=0; already=0; skipped=0
for dir in "${targets[@]}"; do
  [[ "$dir" == "$ROOT" ]] && continue
  s="$(slug "$dir")"
  mem="$PROJECTS/$s/memory"
  rel="../$ROOT_SLUG/memory"   # relative, so it survives moving ~ or the whole tree

  if [[ -L "$mem" ]]; then
    if [[ "$(readlink "$mem")" == "$rel" ]]; then
      echo "  ok       ${dir#"$ROOT"/}"; already=$((already+1)); continue
    fi
    rm -- "$mem"
  elif [[ -d "$mem" ]]; then
    if [[ -n "$(ls -A -- "$mem")" ]]; then
      echo "  SKIP     ${dir#"$ROOT"/} — has $(ls -A -- "$mem" | wc -l) own file(s), merge by hand: $mem"
      skipped=$((skipped+1)); continue
    fi
    rmdir -- "$mem"
  fi

  mkdir -p "$PROJECTS/$s"
  ln -s "$rel" "$mem"
  echo "  linked   ${dir#"$ROOT"/}"; linked=$((linked+1))
done

echo
echo "$linked linked, $already already correct, $skipped skipped"
[[ $skipped -gt 0 ]] && echo "Skipped dirs kept their own memory — move the files into $ROOT_MEM, then re-run."
exit 0
