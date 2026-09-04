# Neovim setup on a new machine

## Prerequisites

### tree-sitter CLI

nvim-treesitter v1 requires the `tree-sitter` CLI to compile parser grammars.
Without it, `ensure_installed` silently does nothing and `:TSUpdate` reports
"all parsers are up-to-date" even though no `.so` files exist.

```sh
npm install -g tree-sitter-cli
```

After installing, open Neovim and run:

```vim
:TSInstall all
```

or let `ensure_installed` handle it on next startup.

**Symptom if missing:** LSP hover (`K`) shows unstyled code blocks -- the
markdown parser runs but language injections (e.g. typescript inside fenced
code blocks) fail because the language-specific parser `.so` files were never
compiled. Neovim's bundled parsers only cover a handful of languages (lua, c,
vim, vimdoc, markdown, query).

### LSP servers

```sh
npm install -g typescript-language-server typescript  # ts_ls
npm install -g vscode-langservers-extracted            # eslint, html, json, css
```

### fff.nvim binary

`fff.nvim` (the fast file picker) needs a native Rust binary. A `PackChanged`
autocmd (`lua/config/pack.lua`) calls `require('fff.download').download_or_build_binary()`
on install/update, which first tries to fetch a prebuilt binary matching the
plugin's pinned rev and **falls back to `cargo build`** if the download fails.

**Symptom if missing:** opening the picker errors with something like
`fff_nvim` / the Rust library not found, and the picker never appears.

Fix — run inside Neovim:

```vim
:lua require('fff.download').download_or_build_binary()
```

If that falls through to a build, it needs `cargo` on `PATH`. Rust isn't
installed system-wide here (it comes from the Nix impero shell), so either
launch `nvim` once from inside `nix develop` (in `~/dev/impero`) so `cargo` is
available, or install rust via `rustup`.

## Custom tooling

### Keybinding usage tracker (`lua/config/usage.lua`)

Answers "which of my custom keybindings do I actually use?" by counting how
often each mapping fires (keyed by mode + `lhs`). It patches `vim.keymap.set`
(loaded first in `lua/config/init.lua`) — it does **not** log typed text, so
there's no keylogger footprint. Counts persist to
`stdpath('data')/keymap-usage.json` and accumulate across sessions.

- `:KeymapStats` — usage table sorted most→least used, plus a "defined but
  never fired this session" list (your prune candidates). Run it *after*
  editing real files, since buffer-local maps (LSP/gitsigns) only register once
  a buffer attaches them.
- `:KeymapStats!` — the same, but including plugin and built-in mappings.
  Patching `vim.keymap.set` catches every map created at runtime, so the plain
  form filters to maps defined under this config; without that the list is
  dominated by Neovim's own `K`, blink's `<Tab>`, and neo-tree's `j`/`k`.
- `:KeymapStatsReset` — wipe the accumulated counts.
