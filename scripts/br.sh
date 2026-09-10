#!/usr/bin/env bash
# Pick a branch (or commit) to check out, with a preview of what it changes.
#
#   br                     # all local branches, newest first
#   br 'sc-40322'          # only refs matching a pattern
#   br main feat/x 9a3f21  # an explicit shortlist - branches or hashes
#
# The preview shows each candidate's commits and diffstat against BASE, so
# A/B-ing several takes on the same problem reads as "what does this one do
# differently" rather than a list of names.
#
# BASE is $BR_BASE, else the remote's default branch (origin/HEAD -> e.g.
# origin/next), else the first origin/{main,master,next,trunk} that resolves,
# else the local branch of that name. Preferring the remote ref keeps the
# preview honest when your local default branch is stale.
set -euo pipefail

resolve_base() {
    # The remote ref, not the local branch of the same name: a local `next`
    # that is 45 commits behind would drown the preview in other people's work.
    remote_head="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [ -n "$remote_head" ]; then
        printf '%s\n' "$remote_head"
        return
    fi
    for candidate in origin/main origin/master origin/next origin/trunk \
                     main master next trunk; do
        if git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return
        fi
    done
    printf 'HEAD\n'
}

BASE="${BR_BASE:-$(resolve_base 2>/dev/null || echo HEAD)}"

# fzf calls this back for the highlighted row; also handy on its own.
if [ "${1:-}" = "--preview" ]; then
    ref="$2"
    merge_base="$(git merge-base "$BASE" "$ref" 2>/dev/null || echo "$BASE")"
    git --no-pager log --color=always --date=short \
        --format='%C(yellow)%h%C(reset) %s%n%C(dim)%ad  %an%C(reset)' \
        "$merge_base..$ref" 2>/dev/null || true
    echo
    git --no-pager diff --color=always --stat "$merge_base..$ref" 2>/dev/null \
        || echo "(nothing to diff against $BASE)"
    exit 0
fi

command -v fzf >/dev/null || { echo "br.sh needs fzf" >&2; exit 1; }
git rev-parse --git-dir >/dev/null

if [ "$#" -gt 1 ]; then
    candidates="$(printf '%s\n' "$@")"
elif [ "$#" -eq 1 ]; then
    candidates="$(git for-each-ref --format='%(refname:short)' \
        --sort=-committerdate refs/heads | grep -- "$1" || true)"
    [ -n "$candidates" ] || { echo "no branch matches '$1'" >&2; exit 1; }
else
    candidates="$(git for-each-ref --format='%(refname:short)' \
        --sort=-committerdate refs/heads)"
fi

current="$(git branch --show-current || echo 'detached')"
dirty=""
git diff --quiet || dirty="  ** uncommitted changes - checkout may fail **"

selected="$(printf '%s\n' "$candidates" | fzf \
    --prompt='checkout > ' \
    --height='90%' --reverse --border --ansi \
    --header="base ${BASE}   on ${current}${dirty}" \
    --preview="$0 --preview {}" \
    --preview-window='right,64%,wrap,border-left')"

[ -n "$selected" ] || exit 0
git checkout "$selected"
