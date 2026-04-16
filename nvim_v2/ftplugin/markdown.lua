-- ── Obsidian: lazy-loaded for Markdown only ───────────────────────────────────
-- This file is sourced automatically by Neovim when a Markdown buffer is opened.

-- Guard: skip floating windows (LSP hover floats are filetype=markdown)
if vim.api.nvim_win_get_config(0).relative ~= '' then return end

-- Guard: only run once
if vim.g._obsidian_loaded then return end
vim.g._obsidian_loaded = true

-- Register with vim.pack (download if missing) and load
vim.pack.add({ 'https://github.com/epwalsh/obsidian.nvim' })

local ok, obsidian = pcall(require, 'obsidian')
if ok then
    obsidian.setup({
        workspaces = { { name = 'personal', path = '~/Documents/inner-sanctum-main' } },
    })
end
