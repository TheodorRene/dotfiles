-- ── Autocommands ──────────────────────────────────────────────────────────────
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Layout ────────────────────────────────────────────────────────────────────
autocmd('VimResized', {
    group    = augroup('equalize_windows', { clear = true }),
    pattern  = '*',
    command  = 'wincmd =',
    desc     = 'Equalize window sizes on terminal resize',
})

-- ── File change detection ─────────────────────────────────────────────────────
-- Reload files that changed on disk when Neovim regains focus or a buffer
-- is entered (matches old config behaviour).
autocmd({ 'FocusGained', 'BufEnter' }, {
    group   = augroup('checktime', { clear = true }),
    pattern = '*',
    command = 'checktime',
    desc    = 'Reload file if changed on disk',
})

-- ── Terminal ──────────────────────────────────────────────────────────────────
autocmd('TermOpen', {
    group   = augroup('terminal_opts', { clear = true }),
    pattern = '*',
    callback = function()
        vim.opt_local.number         = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn     = 'no'
    end,
    desc = 'Disable line numbers and signcolumn in terminal buffers',
})

-- ── Highlight on yank ─────────────────────────────────────────────────────────
autocmd('TextYankPost', {
    group    = augroup('highlight_yank', { clear = true }),
    pattern  = '*',
    callback = function()
        vim.hl.on_yank({ higroup = 'IncSearch', timeout = 150 })
    end,
    desc = 'Briefly highlight yanked text',
})

-- ── Restore cursor position ───────────────────────────────────────────────────
autocmd('BufReadPost', {
    group    = augroup('restore_cursor', { clear = true }),
    pattern  = '*',
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
    desc = 'Restore cursor to last position when reopening a file',
})

-- ── Markdown / gitcommit: spell check, and wrap only where it helps ───────────
-- Guard against floating windows (LSP hover, etc.) which also get
-- filetype=markdown but should never have spell checking applied.
--
-- wrap is set explicitly per filetype rather than left to the global default:
-- it's window-local, so a window that previously held a wrapping buffer would
-- otherwise keep wrap on. Markdown stays unwrapped because soft-wrapped lines
-- interleave badly with markview's in-buffer rendering; gitcommit keeps wrap so
-- long subject/body lines stay readable.
autocmd('FileType', {
    group    = augroup('markdown_opts', { clear = true }),
    pattern  = { 'markdown', 'gitcommit' },
    callback = function(ev)
        -- Skip floating windows (e.g. LSP hover popups)
        if vim.api.nvim_win_get_config(0).relative ~= '' then return end
        vim.opt_local.wrap      = ev.match == 'gitcommit'
        vim.opt_local.spell     = true
        vim.opt_local.spelllang = 'en,nb'   -- English + Norwegian bokmål
    end,
    desc = 'Spell check for markdown / git commits; wrap for gitcommit only',
})

-- ── Remove trailing whitespace on save ────────────────────────────────────────
-- Skipped for filetypes where trailing whitespace is meaningful: in Markdown
-- two trailing spaces are a hard line break, so stripping them silently
-- rewrites the document.
local no_trim = { markdown = true }

autocmd('BufWritePre', {
    group    = augroup('trim_whitespace', { clear = true }),
    pattern  = '*',
    callback = function(ev)
        if no_trim[vim.bo[ev.buf].filetype] then return end
        -- Preserve cursor position; keeppatterns leaves the search register alone
        local pos = vim.api.nvim_win_get_cursor(0)
        vim.cmd([[keeppatterns %s/\s\+$//e]])
        pcall(vim.api.nvim_win_set_cursor, 0, pos)
    end,
    desc = 'Strip trailing whitespace on save',
})

-- ── Macro recording → statusline refresh ─────────────────────────────────────
-- The statusline shows reg_recording() (see options.lua), but statusline
-- redraws are lazy: pressing q to start recording moves no cursor and fires no
-- redraw, so without this the indicator would not appear until some unrelated
-- event repainted it — precisely when you most need it to be immediate.
autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
    group   = augroup('recording_statusline', { clear = true }),
    pattern = '*',
    command = 'redrawstatus',
    desc    = 'Refresh statusline when macro recording starts or stops',
})

-- ── LSP progress → statusline refresh ────────────────────────────────────────
-- vim.lsp.status() consumes progress messages; redraw the statusline each time
-- a new progress event arrives so the message appears promptly and then clears.
autocmd('LspProgress', {
    group   = augroup('lsp_progress_statusline', { clear = true }),
    pattern = '*',
    command = 'redrawstatus',
    desc    = 'Refresh statusline on LSP progress events',
})
