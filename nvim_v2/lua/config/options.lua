local opt = vim.opt
local g   = vim.g

-- ── Leader ────────────────────────────────────────────────────────────────────
g.mapleader      = ' '
g.maplocalleader = ' '

-- ── Disable built-ins we don't want ──────────────────────────────────────────
g.loaded_netrw       = 1  -- replaced by oil.nvim
g.loaded_netrwPlugin = 1

-- ── Mouse / clipboard ─────────────────────────────────────────────────────────
opt.mouse = 'a'
vim.schedule(function()
    opt.clipboard = 'unnamedplus'
end)

-- ── Appearance ────────────────────────────────────────────────────────────────
opt.termguicolors = true
opt.cursorline    = true
opt.colorcolumn   = '120'
opt.showmode      = false       -- mode shown in statusline instead
opt.wrap          = false
opt.breakindent   = true        -- nice for markdown
opt.listchars     = 'tab:▸ ,trail:·,nbsp:␣,extends:❯,precedes:❮'
opt.list          = true
opt.scrolloff     = 10
opt.sidescrolloff = 10
opt.signcolumn    = 'yes'       -- always show, avoids layout jumps
opt.laststatus    = 3           -- single global statusline

-- ── Statusline ────────────────────────────────────────────────────────────────
-- Sections:
--   left:  mode indicator · git branch · filename · modified/RO flags
--   mid:   LSP progress (cleared once consumed by vim.lsp.status())
--   right: filetype · LSP clients · ruler · position
opt.statusline = table.concat({
    '%#StatusLine#',
    ' %{mode()} ',               -- current mode (short)
    '│ %f',                       -- relative filepath
    ' %m%r',                      -- [+] modified, [RO] readonly
    '%=',                         -- switch to right-align
    '%{%v:lua.vim.lsp.status()%}', -- LSP progress (consumed; clears after display)
    ' %=',
    '%y ',                        -- filetype
    '│ %l:%c ',                   -- line:col
    '│ %P ',                      -- scroll percentage
}, '')

-- ── Popup menu appearance ─────────────────────────────────────────────────────
-- autocomplete is intentionally left off: blink.cmp manages its own popup and
-- triggers completion itself. Enabling the native autocomplete would cause two
-- competing popups. blink.cmp also sets completeopt internally, so we only set
-- the purely cosmetic pum options here.
opt.pumborder   = 'rounded'
opt.pummaxwidth = 40

-- ── Splits ───────────────────────────────────────────────────────────────────
opt.splitbelow = true
opt.splitright = true

-- ── Timing ───────────────────────────────────────────────────────────────────
opt.timeoutlen  = 200
opt.ttimeoutlen = 50
opt.updatetime  = 250

-- ── Indentation ──────────────────────────────────────────────────────────────
opt.tabstop     = 4
opt.shiftwidth  = 4
opt.expandtab   = true
opt.smartindent = true

-- ── Search ───────────────────────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase  = true
opt.showmatch  = true

-- ── Files ─────────────────────────────────────────────────────────────────────
opt.autoread = true
opt.swapfile = false
opt.backup   = false
opt.undodir  = os.getenv('HOME') .. '/.vim/undodir'
opt.undofile = true

-- ── Folding (built-in treesitter fold expr, no plugin needed) ─────────────────
opt.foldmethod = 'expr'
opt.foldexpr   = 'v:lua.vim.treesitter.foldexpr()'
opt.foldenable = false   -- open all folds by default on file open

-- ── Diff (0.12 improved defaults, being explicit) ─────────────────────────────
opt.diffopt:append('indent-heuristic')
opt.diffopt:append('inline:char')

-- ── Misc ──────────────────────────────────────────────────────────────────────
opt.cmdheight        = 0          -- ui2 manages the cmdline as a floating window
opt.cdh              = true      -- :cd with no args → home directory
opt.sessionoptions:append('localoptions')

-- SQL completion (bundled with vim, set sensible defaults)
g.sql_type_default        = 'postgresql'
g.omni_sql_default_compl_type = 'syntax'

-- DB UI (vim-dadbod)
g.db                          = vim.env.DB_VAL_LOCAL or ''
g.dbs                         = { val = vim.env.DB_VAL or '', ['val-local'] = vim.env.DB_VAL_LOCAL or '' }
g.db_ui_use_nerd_fonts        = 1
g.db_ui_auto_execute_table_helpers = 1
