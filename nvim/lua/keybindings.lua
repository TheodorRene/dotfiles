local function imap(comb, cmd, desc)
    vim.api.nvim_set_keymap('i', comb, cmd,
                            {noremap = true, silent = true, desc = desc})
end

local function nmap(comb, cmd, desc)
    vim.api.nvim_set_keymap('n', comb, cmd,
                            {noremap = true, silent = true, desc = desc})
end

local function tmap(comb, cmd, desc)
    vim.api.nvim_set_keymap('t', comb, cmd,
                            {noremap = true, silent = true, desc = desc})
end

local function vmap(comb, cmd, desc)
    vim.api.nvim_set_keymap('v', comb, cmd,
                            {noremap = true, silent = true, desc = desc})
end

nmap('<Right>', ':bn <CR>', "Next buffer")
nmap('<Left>', ':bp <CR>', "Previous buffer")

-- leader+a open all folds
nmap('<leader>a', 'zA', "Open all folds")


imap("''", "''<esc>i")
imap("<C-c>", "<Esc>", "Ctrl-c to escape, and not kill anything")
imap('""', '""<esc>i')
imap('$$', '$$<esc>i')
imap('((', '()<esc>i')
imap('[[', '[]<esc>i')
imap('jk', '<esc>')
imap('{{', '{}<esc>i')

-- nmap("<C-e>", "5<C-e>", "Move faster")
-- nmap("<C-y>", "5<C-y>", "Move faster")

nmap("J", "mzJ`z", "Move line under up, but keep cursor position")
nmap("Q", "<nop>", "Disable Ex mode")
-- nmap('<C-d>','<C-d>zz')
-- nmap('<C-u>', '<C-u>zz')
nmap('<Leader>w', ':w<CR>')
nmap('<leader>h', ':nohls<CR>')
nmap('n', 'nzz')
nmap('<leader>;', ':! rocaf %<CR>')

tmap('<Esc>', [[<C-\><C-n>]])

vmap("J", ":m '>+1<CR>gv=gv", "Move line down")
vmap("K", ":m '<-2<CR>gv=gv", "Move line up")

-- Used in gitsigns on_attach
function TRC_GITSIGNS_MAPPINGS(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, opts, desc)
        opts = opts or {}
        opts.buffer = bufnr
        opts.desc = desc
        vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation between hunks
    map('n', ']c', function()
        if vim.wo.diff then return ']c' end
        vim.schedule(function() gs.next_hunk() end)
        return '<Ignore>'
    end, {expr = true, desc = 'next hunk'})

    map('n', '[c', function()
        if vim.wo.diff then return '[c' end
        vim.schedule(function() gs.prev_hunk() end)
        return '<Ignore>'
    end, {expr = true, desc = 'previous hunk'})

    --
    -- Actions
    -- local gitsigns = require('gitsigns')
    map({'n', 'v'}, '<C-g>hs', ':Gitsigns stage_hunk<CR>', {desc = 'stage hunk'})
    map({'n', 'v'}, '<C-g>hr', ':Gitsigns reset_hunk<CR>', {desc = 'reset hunk'})
    map({'n', 'v'}, 'ª', ':Git add %<CR>', {desc = 'stage file AltGr+a'})
    map({'n', 'v'}, 'ß', ':Gitsigns stage_hunk<CR>',
        {desc = 'stage hunk AltGr+s'})
    map({'n', 'v'}, '®', ':Gitsigns reset_hunk<CR>',
        {desc = 'reset hunk AltGr+r'})
    map({'n', 'v'}, 'ü', ':Gitsigns undo_stage_hunk<CR>',
        {desc = 'undo stage hunk AltGr+u'})
    map({'n', 'v'}, 'π', ':Gitsigns preview_hunk_inline<CR>',
        {desc = 'Preview hunk'})
    map({'n', 'v'}, '∫',
        '<cmd>lua require"gitsigns".blame_line{full=true}<CR>',
        {desc = 'Preview hunk'})
    map('n', '<C-g>hu', gs.undo_stage_hunk, {desc = 'undo stage hunk'})
    map('n', '<C-g>td', gs.toggle_deleted, {desc = 'toggle deleted lines'})
    map('n', '<C-g>tl', gs.toggle_linehl, {desc = 'toggle line highlight'})
    -- toggle both deleted and linehl
    map('n', '<C-g>ta', function()
        gs.toggle_deleted()
        gs.toggle_linehl()
    end, {desc = 'toggle deleted and line highlight'})

    -- Text object
    map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>',
        {desc = 'select hunk object'})

end

nmap('<leader>t', ':terminal ', "Run terminal commands")
nmap('<leader>c', ':! ', "Run terminal commands")

-- GIT
nmap('<C-g>c', '<CMD> Telescope git_commits <CR>', "GIT: Commits")
nmap('<C-g>f', '<CMD> Telescope git_bcommits <CR>', "GIT: Buffer Commits")
nmap('<C-g>b', '<CMD> Telescope git_branches <CR>', "GIT: Branches")
nmap('<C-g>s', '<CMD> Git status <CR>', "GIT: status")
nmap('<C-g>p', '<CMD> Git pull  <CR>', "GIT: Pull")
nmap('<C-g>do', '<CMD> DiffviewOpen <CR>', "GIT: Show diff")
nmap('<C-g>dq', '<CMD> DiffviewClose <CR>', "GIT: Close diff")
nmap('<C-g>g', ':Git ', "GIT")
nmap('<C-g>dd', '<CMD> DiffviewOpen develop...HEAD <CR>', "GIT: Diff develop")
nmap('<A-g>', '<CMD> Neogit kind=tab<CR>', "Neogit")

--
nmap('<C-x>m', 'bi[<Esc>ea]()<Esc>hp', "Insert link")

nmap("<leader>m", "@", "Run macro")
-- delete this
nmap("<leader>ll", ":set number | set relativenumber <CR>",
     "Turn on relativenumber")
nmap("<leader>ln", ":set nonumber | set norelativenumber <CR>",
     "Turn off relativenumber")
nmap('<space>f', ':Neoformat <CR>', "Neoformat")
vmap('<space>fs', ':Neoformat! sql<CR>', "Neoformat sql")

vim.cmd [[
        imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
        imap <silent><script><expr> <C-L> copilot#Next()
        imap <silent><script><expr> <C-K> copilot#Previous()
        let g:copilot_no_tab_map = v:true
        ]]

-- Window navigation
function TRC_close_win()
    if vim.bo.modifiable then vim.cmd('w') end
    vim.cmd('q')
end
nmap('<A-c>', '<CMD> lua TRC_close_win() <CR>')
-- function that closes the window and saves if it is modifiable
nmap('<A-,>', '<Cmd>TablineBufferPrevious<CR>', "Previous buffer")
nmap('<A-.>', '<Cmd>TablineBufferNext<CR>', "Next buffer")
nmap('<A-h>', '<C-w>h')
nmap('<A-j>', '<C-w>j')
nmap('<A-k>', '<C-w>k')
nmap('<A-l>', '<C-w>l')
nmap('<A-q>', ':tabprev <CR>')
nmap('<A-w>', ':tabnext <CR>')
nmap('<A-s>', ':vsplit <CR>')
nmap('<A-v>', ':split <CR>')
nmap('<C-W>m', '<Cmd>WinShift<CR>')
nmap('ø', ':vertical resize +10<CR>')
nmap('æ', ':vertical resize -10<CR>')
nmap('å', ':resize -10<CR>')
nmap('Å', ':resize +10<CR>')
--

-- nmap('<C-n>', '<CMD> Telescope file_browser <CR>')
nmap('<C-n>', '<CMD> Oil --float .<CR>')

-- nmap('<C-x>b', '<CMD> Telescope buffers <CR>', "Search open buffers")
nmap('<C-x>f', '<CMD> Telescope current_buffer_fuzzy_find <CR>',
     "Current buffer fuzzy find")
--nmap('<C-x>j', '<CMD> Telescope jumplist <CR>', "Show jumplist")
nmap('<C-x>j', ':lua FzfLua.jumps() <CR>', "Show jumplist")
-- nmap('<C-x>l', '<CMD> Telescope builtin  <CR>', "Search telescope pickers")
nmap('<C-x>l', ':lua FzfLua.builtin() <CR>', "Search FzfLua pickers")
nmap('<C-x>p', ':lua require"telescope.builtin".git_files() <CR>',
     "Search git files from root")
nmap('<C-x>s', "<cmd>lua require('spectre').open()<CR>", "Open Spectre")
nmap('<C-x>z', ':ZenMode <CR>', "Open Zenmode")

-- SQL
nmap('<C-s>d', ':DBUIToggle <CR>', "Open DBUI")
-- nmap('<C-s>i', ':DB g:prod = postgres://folq@localhost<CR>', "Init DB")
nmap('<C-s>r', ':DB ', "Open DB")
nmap('<C-s>f', ':%DB <CR>', "Run file")

-- nmap('<C-p>',
--      ':lua require"telescope.builtin".git_files{use_git_root=false} <CR>',
--      "Search git files")
nmap('<C-p>', ':lua FzfLua.git_files({previewer=false}) <CR>', "Search git files")
-- nmap('<leader>p', ':lua require"telescope.builtin".commands() <CR>',
--      "Search commands")
nmap('<leader>p', ':lua FzfLua.commands() <CR>', "Search commands")

nmap('<leader>b', ':lua FzfLua.buffers() <CR>', "Search open buffers")
nmap('<leader><leader>', ':lua FzfLua.buffers() <CR>', "Search open buffers")
--nmap('<leader>r', '<CMD> Telescope resume <CR>')
nmap('<leader>r', ':lua FzfLua.resume() <CR>', "Resume last FzfLua search")
nmap('<leader>s', ':lua FzfLua.lsp_document_symbols() <CR>',
     "Search document symbols")

-- -- Harpoon
-- nmap('<C-h>a', ':lua require("harpoon.mark").add_file() <CR>',
--      "Harpoon: Add file")
-- nmap('<C-h>m', ':lua require("harpoon.ui").toggle_quick_menu() <CR>',
--      "Harpoon: Show menu")
-- nmap('<C-h>n', ':lua require("harpoon.ui").nav_next() <CR>', "Harpoon: Next")
-- nmap('<C-h>p', ':lua require("harpoon.ui").nav_prev() <CR>', "Harpoon: Previous")

--map('<C-f>', '<CMD> Telescope live_grep <CR>')
nmap('<C-f>', ':lua FzfLua.live_grep() <CR>', "Live grep")
-- nmap('<C-t>', '<CMD> Telescope lsp_dynamic_workspace_symbols <CR>')
nmap('<C-t>', ':lua FzfLua.lsp_live_workspace_symbols() <CR>', "Search workspace symbols")

-- Yank whole file 
nmap('yf', 'ggVGy<C-o>', "Yank whole file")

-- Function keys
nmap('<F3>', ':JestFile <CR>', "Run Jest on file")
nmap('<F4>', ':let @+=expand("%:p")<CR>', "Copy file path to clipboard")
nmap('<F5>', ':e <C-r>+ <CR>', "Open file path from clipboard")
nmap('<F6>', ':UndotreeToggle <CR>', "Show undo tree")
nmap('<F8>', '<Cmd>Lspsaga outline<CR>', "Show LSP Symbols as outline")
nmap('<F9>', ':w <CR> :! rocaf %<CR>')
nmap('<F10>', '<cmd> NvimTreeFindFileToggle<CR>')
nmap('<F12>', '<Cmd> TroubleToggle <CR>', "Show Trouble window")

nmap('<A-r>', ':make run <CR>', "Run make run")

nmap("<A-d>", "<cmd>Lspsaga term_toggle<CR>", "Open terminal")
tmap("<A-d>", "<cmd>Lspsaga term_toggle<CR>", "Open terminal")
-- Goto buffer in position...

-- nmap('<leader>t', 'A,<esc>o"<esc>pa":"<esc>pa"<esc>', "Add translation key")

