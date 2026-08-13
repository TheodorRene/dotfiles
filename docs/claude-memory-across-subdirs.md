# One Claude Code memory across a project's subdirectories

**Status: applied** on 2026-08-13 for `~/dev/impero` (backend, frontend,
frontend/spa, dotnet). Re-run `scripts/install-claude-memory-links.sh` after a
reinstall.

## Why

Claude is often opened in a subdir of impero (`backend/`, `frontend/`) rather
than the repo root. The memory tool's saved facts — the "never run cargo/dotnet
yourself" rules, branch and PR conventions, sparring-partner working style —
were invisible in those sessions, so the same corrections had to be given again.

## Key facts (so this stays correct later)

- **Two different mechanisms, only one is broken.**
  - `CLAUDE.md` is loaded from the cwd **and every parent dir up to `/`**, so
    opening in `backend/` already picks up `~/dev/impero/CLAUDE.md`. Nested
    `CLAUDE.md` files (e.g. `product-wiki/`) load lazily when files there are
    touched. **Nothing to fix here.**
  - The **memory tool** (`MEMORY.md` + one file per fact) lives at
    `~/.claude/projects/<slug>/memory/` and is keyed to the **literal cwd**.
    Each subdir is a separate project → separate, empty memory. This is the
    part that needed fixing.
- **Slug rule**: the absolute path with `/`, `.` and `_` each replaced by `-`;
  case is preserved. `/home/trc/dev/impero/backend` →
  `-home-trc-dev-impero-backend`; `/home/trc/.pi` → `-home-trc--pi`.
- The slug is **not reversible** — `-` could have been any of four characters.
  So the script derives slugs from real directories on disk rather than globbing
  `-home-trc-dev-impero-*`, which would also sweep in a *sibling* project like
  `~/dev/impero-tools`.
- `~/.claude/projects/` is **state, not config** — it is not deployed by
  `symlinkifier.pl` and not in this repo (see REINSTALL.md §1.3). Hence a
  script rather than a symlinkifier line.
- The harness does `mkdir -p` on the memory dir at session start; that is a
  **no-op on an existing symlink**, so the links survive. Verified.
- Links are **relative** (`../-home-trc-dev-impero/memory`) so they survive the
  whole `~/.claude/projects` tree being moved or restored under a different
  path. All slug dirs are flat siblings, so `..` is always `projects/`.

## What was done

`scripts/install-claude-memory-links.sh` — replaces each subdir's memory dir
with a symlink to the project root's:

```
~/.claude/projects/-home-trc-dev-impero-backend/memory
  -> ../-home-trc-dev-impero/memory
```

```sh
scripts/install-claude-memory-links.sh                    # defaults to ~/dev/impero
scripts/install-claude-memory-links.sh ~/dev/impero tools # force a subdir not yet opened
scripts/install-claude-memory-links.sh ~/dev/other-proj   # any other project
```

Idempotent. With no subdir args it links every subdir (2 levels deep) that
already has a project dir. A subdir memory dir containing **real files** is
reported and left alone — merge it into the root by hand, then re-run.

## Verify

```sh
ls ~/.claude/projects/-home-trc-dev-impero-backend/memory/   # lists the shared files
readlink ~/.claude/projects/-home-trc-dev-impero-dotnet/memory
```

Checked when applied: read-through lists all files incl. `MEMORY.md`; a write
via `frontend/memory/` lands in the root dir; `mkdir -p` leaves the link intact.

## Gotchas

- A memory written from `backend/` lands in the shared pile with **nothing
  marking it backend-specific** — lean on the `description:` frontmatter line to
  disambiguate, or the fact will look global.
- **New subdirs are not linked automatically.** First time Claude is opened in
  a new subdir it gets its own empty memory; re-run the script.
- `~/` itself (`-home-trc`) is a separate project with its own memory and is
  deliberately **not** linked to impero's.

## After a reinstall

`~/.claude/` is restored from backup (REINSTALL.md §3.6), and tar preserves
symlinks, so the links usually come back on their own. If `~/.claude` was **not**
restored, or new subdirs appeared since, just re-run the script — it is safe
either way.
