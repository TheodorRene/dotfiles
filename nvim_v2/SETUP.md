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
