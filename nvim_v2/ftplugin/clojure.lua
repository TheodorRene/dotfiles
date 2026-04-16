-- ── Conjure: lazy-loaded for Clojure only ─────────────────────────────────────
-- This file is sourced automatically by Neovim when a Clojure buffer is opened.
-- We register the plugin, set g: vars, then packadd so conjure activates.

-- Guard: only run once
if vim.g._conjure_loaded then return end
vim.g._conjure_loaded = true

-- Restrict conjure to Clojure only (prevent REPL auto-spawn for other FTs)
vim.g["conjure#filetypes"]           = { "clojure" }
vim.g["conjure#filetype#javascript"] = false
vim.g["conjure#filetype#typescript"] = false
vim.g["conjure#filetype#python"]     = false
vim.g["conjure#filetype#lua"]        = false
vim.g["conjure#filetype#rust"]       = false
vim.g["conjure#filetype#sql"]        = false

-- Register with vim.pack (download if missing) and load
vim.pack.add({ 'https://github.com/Olical/conjure' })
