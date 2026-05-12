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
