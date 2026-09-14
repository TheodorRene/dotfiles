# Neovim config (nvim_v2)

Symlinked to `~/.config/nvim` by `symlinkifier.pl`. The repo-root `agents.md`
still applies (machine, conventions, "no sudo from here"); this file covers only
what's specific to the editor config. New-machine prerequisites — tree-sitter
CLI, LSP server installs, the fff.nvim binary — live in `SETUP.md`, not here.

## Shape

- **Neovim 0.12**, and the config leans on 0.12 features deliberately. Advice
  written for 0.9/0.10 or for lazy.nvim usually does not apply.
- **Plugin manager is built-in `vim.pack`** — not lazy.nvim, not packer. It is
  **not a lazy-loading framework**: everything in `vim.pack.add({...})` loads at
  startup. The plugin list is kept lean on purpose.
- **LSP is native** — `vim.lsp.config[name]` + `vim.lsp.enable(name)`. There is
  **no nvim-lspconfig**. Mason is installed for *binaries only* (no
  mason-lspconfig), and `setup('mason')` must stay eager because it prepends
  `mason/bin` to `$PATH`.
- Statusline is a hand-rolled `opt.statusline` string (no lualine), with
  `laststatus=3`. `cmdheight=0` because `vim._core.ui2` owns the cmdline.

## Load order (`lua/config/init.lua`)

`usage` → `options` → `pack` → `diagnostics` → `lsp` → `keymaps` → `autocmds` →
`commands`, then `ui2.enable()`.

**`config.usage` must stay first.** It monkeypatches `vim.keymap.set`, so any
mapping defined before it loads is invisible to the usage tracker. `options` and
`pack` precede `keymaps`/`lsp` so plugins exist before anything references them.

## Conventions

- **Plugin config is co-located with the plugin declaration** in `pack.lua`,
  deliberately, for discoverability. Exceptions: LSP-adjacent config goes in
  `lsp.lua` / `diagnostics.lua`.
- `pack.lua` wraps every `require` in a local `setup()` helper that `pcall`s, so
  a first boot (plugins not yet on disk) doesn't hard-error.
- One shared LSP `on_attach` in `lsp.lua` is applied by looping over a `servers`
  list; it's also exported as `_G.LSP_ON_ATTACH` and wired into
  `vim.g.rustaceanvim` (rustaceanvim runs its own client, so it bypasses
  `vim.lsp.enable`).
- Keymaps use the local `map`/`nmap`/`imap`/`vmap`/`tmap` wrappers
  (noremap + silent by default). Buffer-local LSP maps live in `on_attach`.

## Lazy loading, when it's actually needed

`vim.pack` has no lazy support, so the escape hatch is **`vim.pack.add()` inside
an `ftplugin/` file**, guarded by a `vim.g._*_loaded` flag:

- `ftplugin/clojure.lua` → conjure
- `ftplugin/markdown.lua` → obsidian.nvim

Use that pattern for anything heavy and language-specific rather than adding it
to the startup list.

## Keymap design constraints

The keyboard is a **ZSA Voyager with home row mods**, and `timeoutlen = 200`.
Together these make **multi-key sequences unreliable**: the second key has to
land inside 200 ms, and home-row-mod tap/hold resolution jitters enough to miss
it. A missed window doesn't just fail — the prefix key fires its default action.

- Prefer **`<leader>` sequences** (Space is a thumb key with no tap/hold
  ambiguity, and which-key waits on the prefix indefinitely) or **single
  modifier chords**. Avoid inventing new `<C-x>`-style two-key sequences.
- Prefix keys already in use: `<C-a>`, `<C-x>`, `<C-g>`, `<C-s>`, `<leader>`.
- Nordic AltGr characters are mapped directly as keys (`ø æ å Å`, and
  `ª ß ® ü π ∫` for gitsigns). Don't "fix" these into ASCII.

## Gotchas

- **Treesitter rtp is `append`ed, not prepended** (`pack.lua`). nvim-treesitter
  v1 ships queries under `runtime/queries/`, but the 7 parsers bundled with 0.12
  (lua, c, vim, vimdoc, markdown, markdown_inline, query) need `$VIMRUNTIME`
  queries to win, or you get "Invalid field name" errors. Don't flip it.
- **Diagnostic signs cannot use `sign_define()` in 0.12** — only
  `vim.diagnostic.config({ signs = { text = ... } })`.
- **Borders come from `opt.winborder`**, so hover/float/blink configs mostly
  don't need an explicit `border`.
- **Markdown is intentionally unwrapped** (soft wrap fights markview's in-buffer
  rendering) and is **exempt from trailing-whitespace trimming** (two trailing
  spaces are a hard line break). gitcommit still wraps.
- **blink.cmp uses `preset = 'none'`** — every mapping is explicit, and native
  autocomplete stays off so two popups don't compete.
- **focus.nvim** is excluded from sidebars/panels via `focus_disable`; extend the
  lists in `pack.lua` when adding a new panel plugin.
- `NVIM_SKIP_LSP_CONF=1` skips all LSP setup — useful for fast/headless runs.

## Updating plugins

`:lua vim.pack.update()`. `PackChanged` autocmds then run `:TSUpdate` and
re-fetch the fff.nvim binary automatically. **`nvim-pack-lock.json` is version
controlled — commit it** with the change. Some plugins are pinned by tag or
range (blink.cmp, rustaceanvim, haskell-tools, neo-tree); bump the `version` in
`pack.lua` to move those.

## Keybinding usage tracker

`lua/config/usage.lua` counts how often each mapping fires (mode + lhs) — it
records *only* that a mapping triggered, never typed text. Any new keymap is
picked up automatically. Counts persist to
`stdpath('data')/keymap-usage.json`; `:KeymapStatsReset` clears them.

Because patching `vim.keymap.set` catches **every** mapping created at runtime —
Neovim's own LSP defaults, plugin buffer-local maps — each record stores the
file that defined it. `:KeymapStats` filters to maps from this config;
`:KeymapStats!` shows everything. When editing the report, note that ownership
for records predating that field is backfilled by matching **mode + lhs**, not
lhs alone: a visual-mode `K` here must not claim Neovim's normal-mode `K`.

## :DebugAI — state capture for intermittent bugs

`lua/config/debugai.lua`, lazily required from the `:DebugAI` command. Run it
**the moment something misbehaves**; it writes a markdown report to
`stdpath('state')/debug-ai/<timestamp>.md` plus a `latest.md` copy, and puts the
path on the clipboard.

    :DebugAI                    -- bare report
    :DebugAI grr did nothing    -- with a description of the symptom
    :DebugAI!                   -- also appends the tail of the LSP log

Captures the session, attached LSP clients and their `root_dir`s, a probe table
of keys that matter (including bare-key controls like `K`), which-key's trigger
mappings, and `:messages`. **`:messages` is the point** — with `cmdheight=0` and
ui2, a thrown error has nowhere visible to land, so "nothing happened" and "it
threw" look identical on screen.

The report deliberately lives outside this repo: it contains absolute paths,
buffer names and message text, and this repo is public.

**Reading it:** the discriminator is bare keys vs prefixed ones. which-key
installs **buffer-local** triggers on every prefix in use here — `<Space>`, `g`,
`z`, `[`, `]`, `<C-A>`, `<C-G>`, `<C-X>`, `<C-W>` — so anything under those
routes through which-key, while `K` and other bare keys do not. If the bare-key
controls work and the prefixed ones don't, suspect the trigger layer, not LSP.

**Don't** probe which-key by calling `wk.show()`: it opens a popup as a side
effect and throws whenever which-key isn't UI-initialised, which reads as a
failure when nothing is wrong. That mistake was made and removed once already.

## Verifying a change without opening the editor

Headless runs load the real config and surface Lua errors:

```sh
NVIM_SKIP_LSP_CONF=1 nvim --headless -u init.lua \
  -c 'lua print(vim.wo.wrap)' -c 'qa!'
```

Prefer asserting on observable state (`vim.wo.*`, `vim.b.*`, `vim.fn.exists(':Cmd')`,
extmark counts) over eyeballing. Note that neo-tree and trouble don't render as
real sidebars headlessly, so test *their* wiring by firing the autocmd and
checking the variable rather than by opening the panel.
