# Cap rust-analyzer in a memory-limited cgroup

## Why

On 2026-06-23 the desktop session was killed (logged out) by `systemd-oomd`.
The kernel OOM table showed the cause: **two `rust-analyzer` instances at
~10 GB each (~20 GB combined)** on the large impero workspace (~40 crates),
alongside the .NET backend (~6 GB) and webpack — together blowing past 30 GB
RAM. The existing zram + oomd pressure tuning helped but couldn't absorb a
spike that large/fast, so oomd killed the whole `session.scope` (82 processes).

Goal: bound rust-analyzer's memory in its own cgroup so the **kernel
reclaims/kills RA inside that group** before system-wide pressure makes oomd
take down the session. i.e. "RA dies/restarts, the desktop survives."

## Key facts (so this stays correct later)

- `~/dev/impero` is a **Nix flake dev shell** (`~/dev/impero/flake.nix`).
  `backend/rust-toolchain.toml` declares `components = ["rust-analyzer"]`, so RA
  comes from the **Nix store** on `PATH` inside `nix develop`. nvim / zellij /
  claude all run inside that shell.
- Don't wrap the RA *binary*: its `/nix/store/...` path changes per toolchain
  and Nix prepends its bin (shadowing any `~/.local/bin` shim). Instead change
  only the **cgroup** RA launches into; leave the binary + env untouched.
- It will still use the Nix RA. Launch becomes
  `systemd-run --user --scope --slice=rust-analyzer.slice -- <abs path to RA>`.
  `--scope` (not `--service`) **inherits the caller's full environment**, so
  `RUSTUP_TOOLCHAIN`, `RUST_SRC_PATH`, `LIBCLANG_PATH`, cwd, and the LSP stdio
  pipes are all preserved.
- The cap is **collective** across all RA instances in the slice — two nvim
  panes can't sum to 20 GB. One healthy RA fits; a duplicate gets squeezed and
  one is OOM-killed *within the slice* (RA restarts; session stays up).
- rustaceanvim v9.0.1 contract (verified in its source):
  - `server.cmd` accepts a **function returning `string[]`**
    (`config/internal.lua:282`). With a function, `auto_attach` skips its
    executable check (`config/internal.lua:273-280`).
  - LSP start only checks `cmd[1]` is executable (`lsp/init.lua:263`) —
    `systemd-run` is, so it passes.
  - Default resolution is PATH via `vim.fn.exepath('rust-analyzer')`
    (`config/internal.lua:16`); no rustup/mason for RA.
  - **Cosmetic caveat**: `:checkhealth rustaceanvim` runs `cmd[1] --version`
    (= `systemd-run --version`) so it misreports the RA version. LSP behaviour
    (hover, inlay hints, clippy-on-save, `:RustAnalyzer` over RPC) is fine.

## Changes (all via the dotfiles + symlink pattern)

### 1. New `systemd/user/rust-analyzer.slice` (in dotfiles)

```ini
# Memory-capped cgroup for rust-analyzer. Launched into via
# nvim_v2/lua/config/lsp.lua -> vim.g.rustaceanvim.server.cmd.
# Collective cap across all RA instances. Tune to RAM/workload.
[Slice]
MemoryHigh=12G
MemoryMax=15G
```

`MemoryHigh` = soft throttle/reclaim point; `MemoryMax` = hard ceiling (kernel
OOM-kills within the cgroup past this). 12G/15G is a starting point for a 30 GB
machine running the .NET backend too — adjust after observing real usage.

### 2. `symlinkifier.pl` — add an individual-file symlink

Same style as the existing `claude/settings.json` lines (single file under
`~/.config`, not a whole dir):

```perl
symlink_path("$dotfiles/systemd/user/rust-analyzer.slice",
             "$home/.config/systemd/user/rust-analyzer.slice");
```

### 3. `nvim_v2/lua/config/lsp.lua` — add `cmd` to `vim.g.rustaceanvim.server`

The `server` table currently has `on_attach` + `default_settings` (lines
272–303). Add a `cmd` function that resolves RA's absolute path via
`vim.fn.exepath` (the Nix-store binary, since nvim runs inside `nix develop`)
and hands it to systemd-run, with a fallback if systemd-run is missing:

```lua
cmd = function()
    local ra = vim.fn.exepath('rust-analyzer')
    if ra == '' then ra = 'rust-analyzer' end
    if vim.fn.executable('systemd-run') == 1 then
        return { 'systemd-run', '--user', '--scope', '--quiet', '--collect',
                 '--slice=rust-analyzer.slice', '--', ra }
    end
    return { ra }
end,
```

## Activate

```sh
perl ~/dotfiles/symlinkifier.pl     # creates the slice symlink (user-level, no sudo)
systemctl --user daemon-reload      # pick up the slice unit
# restart nvim on the impero project; RA re-attaches
```

## Verify

- LSP works: hover, inlay hints, clippy-on-save, `:RustAnalyzer` — confirms
  stdio + nix env survived the `systemd-run --scope` wrapper.
- With RA running:
  - `systemctl --user status rust-analyzer.slice` shows the RA scope(s) under it.
  - `systemd-cgls --user` shows RA in `rust-analyzer.slice`, NOT `session.scope`.
  - `cat /proc/$(pgrep -f rust-analyzer | head -1)/cgroup` ends in
    `rust-analyzer.slice/...`.
- Stress (optional): open the project in two nvim panes; combined RA memory is
  bounded and, under squeeze, an RA is killed/restarted while the desktop
  session stays up (no logout).

## Open items

- Is the *second* RA really from Claude Code, or just a second nvim? Confirm by
  inspecting a live RA's parent/cgroup (`cat /proc/PID/cgroup`). If a non-nvim
  spawner is involved, it needs its own hook to land in the slice.
- Cap tuning (12G/15G) once real usage is observed.

## Commit (per agents.md conventions)

Commit directly to `main`, no branch, no Claude attribution. Suggested: one
commit for the slice + `symlinkifier.pl`, one for the nvim `cmd` override. Hold
until verified RA still attaches (the override could break Rust LSP if wrong).
