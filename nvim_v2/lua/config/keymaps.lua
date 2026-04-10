-- ── Keymaps ───────────────────────────────────────────────────────────────────
-- Helper wrappers (noremap + silent by default)
local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = desc })
end
local function nmap(lhs, rhs, desc) map('n', lhs, rhs, desc) end
local function imap(lhs, rhs, desc) map('i', lhs, rhs, desc) end
local function vmap(lhs, rhs, desc) map('v', lhs, rhs, desc) end
local function tmap(lhs, rhs, desc) map('t', lhs, rhs, desc) end

-- ── Insert mode conveniences ──────────────────────────────────────────────────
imap('jk',   '<Esc>',     'Escape')
imap('<C-c>', '<Esc>',    'Ctrl-C as Escape (no side effects)')
imap("''",   "''<Esc>i",  'Auto-close single quotes')
imap('""',   '""<Esc>i',  'Auto-close double quotes')
imap('$$',   '$$<Esc>i',  'Auto-close dollar signs')
imap('((',   '()<Esc>i',  'Auto-close parens')
imap('[[',   '[]<Esc>i',  'Auto-close brackets')
imap('{{',   '{}<Esc>i',  'Auto-close braces')

-- ── Copilot (insert mode) ─────────────────────────────────────────────────────
-- Vimscript needed because copilot#Accept returns an expression
vim.cmd([[
    imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
    imap <silent><script><expr> <C-L> copilot#Next()
    imap <silent><script><expr> <C-K> copilot#Previous()
]])

-- ── Normal mode essentials ────────────────────────────────────────────────────
nmap('J',          'mzJ`z',           'Join line, keep cursor position')
nmap('Q',          '<nop>',           'Disable Ex mode')
nmap('n',          'nzz',             'Next search result (centred)')
nmap('<Leader>w',  ':w<CR>',          'Save file')
nmap('<leader>h',  ':nohls<CR>',      'Clear search highlight')
nmap('<leader>a',  'zA',              'Toggle all folds')
nmap('<leader>;',  ':! rocaf %<CR>',  'Run rocaf on file')
nmap('<leader>t',  ':terminal ',      'Open terminal with command')
nmap('<leader>c',  ':! ',             'Run shell command')
nmap('<leader>z',  ':ZenMode<CR>',    'Zen mode')
nmap('<leader>o',  ':call Open_pdf()<CR>', 'Open PDF with same name')

-- Insert markdown link around word
nmap('<C-x>m', 'bi[<Esc>ea]()<Esc>hp', 'Wrap word in markdown link')

-- Macro shortcut
nmap('<leader>m', '@', 'Run macro')

-- Line number toggles
nmap('<leader>ll', ':set number | set relativenumber<CR>',   'Enable relative numbers')
nmap('<leader>ln', ':set nonumber | set norelativenumber<CR>', 'Disable line numbers')

-- ── Visual mode ───────────────────────────────────────────────────────────────
vmap('J',          ":m '>+1<CR>gv=gv", 'Move selection down')
vmap('K',          ":m '<-2<CR>gv=gv", 'Move selection up')

-- ── Terminal mode ─────────────────────────────────────────────────────────────
tmap('<Esc>', [[<C-\><C-n>]], 'Exit terminal mode')

-- ── Formatting ───────────────────────────────────────────────────────────────
nmap('<space>f', function()
    require('conform').format({ async = true, lsp_fallback = true })
end, 'Format file (conform)')
vmap('<space>fs', function()
    require('conform').format({ async = true, formatters = { 'sqlfmt' } })
end, 'Format SQL selection (conform)')

-- ── Buffer navigation ─────────────────────────────────────────────────────────
nmap('<Right>',  ':bn<CR>',                       'Next buffer')
nmap('<Left>',   ':bp<CR>',                       'Previous buffer')
nmap('<A-,>',    '<Cmd>BufferLineCyclePrev<CR>',  'Previous buffer (tabline)')
nmap('<A-.>',    '<Cmd>BufferLineCycleNext<CR>',  'Next buffer (tabline)')

-- ── Window navigation ─────────────────────────────────────────────────────────
nmap('<A-h>', '<C-w>h',         'Window left')
nmap('<A-j>', '<C-w>j',         'Window down')
nmap('<A-k>', '<C-w>k',         'Window up')
nmap('<A-l>', '<C-w>l',         'Window right')
nmap('<A-s>', ':vsplit<CR>',    'Vertical split')
nmap('<A-v>', ':split<CR>',     'Horizontal split')
nmap('<A-q>', ':tabprev<CR>',   'Previous tab')
nmap('<A-w>', ':tabnext<CR>',   'Next tab')
nmap('<A-c>', '<CMD>lua TRC_close_win()<CR>', 'Save and close window')

-- Window resize (Nordic keyboard: ø æ å Å)
nmap('ø', ':vertical resize +10<CR>', 'Resize window wider')
nmap('æ', ':vertical resize -10<CR>', 'Resize window narrower')
nmap('å', ':resize -10<CR>',          'Resize window shorter')
nmap('Å', ':resize +10<CR>',          'Resize window taller')

-- ── Tab page navigation ───────────────────────────────────────────────────────
nmap('<A-q>', ':tabprev<CR>',  'Previous tab page')
nmap('<A-w>', ':tabnext<CR>',  'Next tab page')

-- ── File manager ──────────────────────────────────────────────────────────────
nmap('<C-n>', '<CMD>Oil --float .<CR>', 'Open Oil file manager (float)')

-- ── Fuzzy finding (fzf-lua) ───────────────────────────────────────────────────
local fzf = function(fn, opts)
    return function() require('fzf-lua')[fn](opts or {}) end
end

nmap('<C-t>',         fzf('lsp_live_workspace_symbols'),        'FZF: workspace symbols')
nmap('<leader>p',     fzf('commands'),                          'FZF: commands')
nmap('<leader>r',     fzf('resume'),                            'FZF: resume last')
nmap('<leader>s',     fzf('lsp_document_symbols'),              'FZF: document symbols')
nmap('<leader>b',     fzf('buffers'),                           'FZF: buffers')
nmap('<leader><leader>', fzf('buffers'),                        'FZF: buffers')
nmap('<C-x>j',        fzf('jumps'),                             'FZF: jumplist')
nmap('<C-x>l',        fzf('builtin'),                           'FZF: pickers')
nmap('<C-x>f',        fzf('blines'),                            'FZF: current buffer lines')

-- ── fff.nvim ──────────────────────────────────────────────────────────────────
-- <C-p>: file picker  <C-f>: fuzzy grep
-- ff/fg/fz/fc: alternative bindings
nmap('<C-p>', function() require('fff').find_files() end,                         'FFF: find files')
nmap('<C-f>', function() require('fff').live_grep() end,                          'FFF: live grep')
nmap('ff',   function() require('fff').find_files() end,                          'FFF: find files')
nmap('fg',   function() require('fff').live_grep() end,                           'FFF: live grep')
nmap('fz',   function() require('fff').live_grep({ grep = { modes = { 'fuzzy', 'plain' } } }) end, 'FFF: fuzzy grep')
nmap('fc',   function() require('fff').live_grep({ query = vim.fn.expand('<cword>') }) end,        'FFF: grep word')

-- ── Git ───────────────────────────────────────────────────────────────────────
nmap('<C-g>c',  function() require('fzf-lua').git_commits() end,       'GIT: commits')
nmap('<C-g>f',  function() require('fzf-lua').git_bcommits() end,      'GIT: buffer commits')
nmap('<C-g>b',  function() require('fzf-lua').git_branches() end,      'GIT: branches')
nmap('<C-g>s',  '<CMD>Git status<CR>',                     'GIT: status (fugitive)')
nmap('<C-g>p',  '<CMD>Git pull<CR>',                       'GIT: pull')
nmap('<C-g>do', '<CMD>DiffviewOpen<CR>',                   'GIT: open diffview')
nmap('<C-g>dq', '<CMD>DiffviewClose<CR>',                  'GIT: close diffview')
nmap('<C-g>g',  ':Git ',                                   'GIT: fugitive command')
nmap('<C-g>dd', '<CMD>DiffviewOpen develop...HEAD<CR>',    'GIT: diff vs develop')
nmap('<A-g>',   '<CMD>Neogit kind=tab<CR>',                'Neogit (tab)')

-- ── Gitsigns mappings (set in on_attach via gitsigns setup in pack.lua) ───────
-- GITSIGNS_MAPPINGS is called from gitsigns on_attach
function GITSIGNS_MAPPINGS(bufnr)
    local gs = package.loaded.gitsigns
    local function bmap(mode, lhs, rhs, opts, desc)
        opts = vim.tbl_extend('force', opts or {}, { buffer = bufnr, desc = desc })
        vim.keymap.set(mode, lhs, rhs, opts)
    end

    -- Navigation between hunks
    bmap('n', ']c', function()
        if vim.wo.diff then return ']c' end
        vim.schedule(function() gs.next_hunk() end)
        return '<Ignore>'
    end, { expr = true }, 'Gitsigns: next hunk')

    bmap('n', '[c', function()
        if vim.wo.diff then return '[c' end
        vim.schedule(function() gs.prev_hunk() end)
        return '<Ignore>'
    end, { expr = true }, 'Gitsigns: prev hunk')

    -- Stage / reset / undo
    bmap({ 'n', 'v' }, '<C-g>hs', ':Gitsigns stage_hunk<CR>',      {}, 'Gitsigns: stage hunk')
    bmap({ 'n', 'v' }, '<C-g>hr', ':Gitsigns reset_hunk<CR>',      {}, 'Gitsigns: reset hunk')
    bmap('n',          '<C-g>hu', gs.undo_stage_hunk,               {}, 'Gitsigns: undo stage hunk')
    bmap('n',          '<C-g>td', gs.toggle_deleted,                {}, 'Gitsigns: toggle deleted')
    bmap('n',          '<C-g>tl', gs.toggle_linehl,                 {}, 'Gitsigns: toggle line highlight')
    bmap('n',          '<C-g>ta', function()
        gs.toggle_deleted()
        gs.toggle_linehl()
    end, {}, 'Gitsigns: toggle deleted + line highlight')

    -- Nordic keyboard AltGr shortcuts
    bmap({ 'n', 'v' }, 'ª', ':Git add %<CR>',                       {}, 'GIT: stage file (AltGr+a)')
    bmap({ 'n', 'v' }, 'ß', ':Gitsigns stage_hunk<CR>',             {}, 'Gitsigns: stage hunk (AltGr+s)')
    bmap({ 'n', 'v' }, '®', ':Gitsigns reset_hunk<CR>',             {}, 'Gitsigns: reset hunk (AltGr+r)')
    bmap({ 'n', 'v' }, 'ü', ':Gitsigns undo_stage_hunk<CR>',        {}, 'Gitsigns: undo stage (AltGr+u)')
    bmap({ 'n', 'v' }, 'π', ':Gitsigns preview_hunk_inline<CR>',    {}, 'Gitsigns: preview hunk (AltGr+p)')
    bmap({ 'n', 'v' }, '∫', '<cmd>lua require"gitsigns".blame_line{full=true}<CR>', {}, 'Gitsigns: blame line (AltGr+b)')

    -- Text object: ih = in hunk
    bmap({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', {}, 'Gitsigns: select hunk (text object)')
end

-- ── Flash ────────────────────────────────────────────────────────────────────
map({'n','x','o'}, 's', function() require('flash').jump() end,       'Flash: jump')
map({'n','x','o'}, 'S', function() require('flash').treesitter() end, 'Flash: treesitter')

-- ── lspsaga: floating terminal only ──────────────────────────────────────────
nmap('<A-d>', '<cmd>Lspsaga term_toggle<CR>', 'Lspsaga: floating terminal')
tmap('<A-d>', '<cmd>Lspsaga term_toggle<CR>', 'Lspsaga: floating terminal (close)')

-- ── SQL / DB ──────────────────────────────────────────────────────────────────
nmap('<C-s>d', ':DBUIToggle<CR>', 'DB: toggle UI')
nmap('<C-s>r', ':DB ',           'DB: run query')
nmap('<C-s>f', ':%DB<CR>',       'DB: run file')

-- ── Search / replace ─────────────────────────────────────────────────────────
nmap('<C-x>s', "<cmd>lua require('spectre').open()<CR>", 'Spectre: open')
nmap('<C-x>z', ':ZenMode<CR>',                           'ZenMode: toggle')

-- ── Yank helpers ─────────────────────────────────────────────────────────────
nmap('yf', 'ggVGy<C-o>', 'Yank whole file')

-- ── make ─────────────────────────────────────────────────────────────────────
nmap('<A-r>', ':make run<CR>', 'Run make run')

-- ── Function keys ─────────────────────────────────────────────────────────────
nmap('<F4>',  ':let @+=expand("%:p")<CR>',  'Copy file path to clipboard')
nmap('<F5>',  ':e <C-r>+<CR>',              'Open file path from clipboard')
nmap('<F6>',  ':Undotree<CR>',              'Built-in Undotree (0.12)')
nmap('<F9>',  ':w<CR>:! rocaf %<CR>',       'Save and run rocaf')
nmap('<F12>', '<Cmd>Trouble diagnostics<CR>', 'Trouble: workspace diagnostics')

-- ── Window helper ─────────────────────────────────────────────────────────────
function TRC_close_win()
    if vim.bo.modifiable then vim.cmd('w') end
    vim.cmd('q')
end

-- ── Open PDF with matching filename ───────────────────────────────────────────
vim.cmd([[
if !exists('*Open_pdf')
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif
]])
