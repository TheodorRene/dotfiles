local function imap(comb, cmd, desc)
	vim.api.nvim_set_keymap('i', comb, cmd, {noremap = true, silent = true, desc = desc})
end

local function nmap(comb, cmd, desc)
	vim.api.nvim_set_keymap('n', comb, cmd, {noremap = true, silent = true, desc = desc})
end

local function tmap(comb, cmd, desc)
	vim.api.nvim_set_keymap('t', comb, cmd, {noremap = true, silent = true, desc = desc})
end

local function vmap(comb, cmd, desc)
	vim.api.nvim_set_keymap('v', comb, cmd, {noremap = true, silent = true, desc = desc})
end
imap('jk', '<esc>')
nmap('<C-W>m','<Cmd>WinShift<CR>')
nmap('€', '<Cmd>WinShift<CR>')

nmap('<Leader>w',':w<CR>')
nmap('<M-v>', ':split <CR>')
nmap('<M-s>', ':vsplit <CR>')
nmap('<F4>', ':let @+=expand("%:p")<CR>', "Copy file path to clipboard")
nmap('<F5>', ':e <C-r>+ <CR>', "Copy file path to clipboard")




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
    end, {expr=true, desc='next hunk'})

    map('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.prev_hunk() end)
      return '<Ignore>'
    end, {expr=true, desc='previous hunk'})

    -- Actions
    map({'n', 'v'}, '<C-g>hs', ':Gitsigns stage_hunk<CR>', {desc='stage hunk'})
    map({'n', 'v'}, '<C-g>hr', ':Gitsigns reset_hunk<CR>', {desc='reset hunk'})
    map('n', '<C-g>hu', gs.undo_stage_hunk, {desc='undo stage hunk'})
    map('n', '<C-g>td', gs.toggle_deleted, {desc='toggle deleted lines'})
    map('n', '<C-g>tl', gs.toggle_linehl, {desc='toggle line highlight'})

    -- Text object
    map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>', {desc='select hunk object'})

end
-- Git
nmap('<C-g>c', '<CMD> Telescope git_commits <CR>', "GIT: Commits")
nmap('<C-g>f', '<CMD> Telescope git_bcommits <CR>', "GIT: Buffer Commits")
nmap('<C-g>b', '<CMD> Telescope git_branches <CR>', "GIT: Branches")
nmap('<C-g>s', '<CMD> Git status <CR>', "GIT: status")
nmap('<C-g>w', ':vsplit term://git status <CR>', "GIT: status")
nmap('ß', ':vsplit term://git status <CR>', "GIT: status")
nmap('<C-g>p', '<CMD> Git pull  <CR>', "GIT: Pull")
nmap('<C-g>do', '<CMD> DiffviewOpen <CR>', "GIT: Show diff")
nmap('<C-g>dq', '<CMD> DiffviewClose <CR>', "GIT: Close diff")
nmap('<C-g>g', ':Git ', "GIT")
nmap('<C-g>dd', '<CMD> DiffviewOpen develop...HEAD <CR>', "GIT: Diff develop")
nmap('<A-g>', '<CMD> Neogit <CR>', "Neogit")
local function starts_with(str, start)
   return string.find(str, start) == 1
end

nmap('<leader>t', 'A,<esc>o"<esc>pa":"<esc>pa"<esc>', "Add translation key")

vmap("J", ":m '>+1<CR>gv=gv", "Move line down")
vmap("K", ":m '<-2<CR>gv=gv", "Move line up")
nmap("<leader>ll", ":set number | set relativenumber <CR>", "Move line up")
vmap("<leader>ll", ":set number | set relativenumber <CR>", "Move line up")
nmap("<leader>ln", ":set nonumber | set norelativenumber <CR>", "Move line up")
vmap("<leader>ln", ":set nonumber | set norelativenumber <CR>", "Move line up")


nmap("J", "mzJ`z", "Move line under up, but keep cursor position")

nmap("Q", "<nop>", "Disable Ex mode")
imap("<C-c>", "<Esc>", "Ctrl-c to escape, and not kill anything")

vim.cmd[[
        imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
        let g:copilot_no_tab_map = v:true
        ]]

nmap('<M-h>', '<C-w>h')
nmap('<M-j>', '<C-w>j')
nmap('<M-k>', '<C-w>k')
nmap('<M-l>', '<C-w>l')
nmap('<M-q>', '<Cmd>TablineBufferPrevious<CR>', "Previous buffer")
nmap('<M-w>', '<Cmd>TablineBufferNext<CR>', "Next buffer")


nmap('<C-n>', '<CMD> Telescope file_browser <CR>')
-- nmap('/', '<CMD> Telescope current_buffer_fuzzy_find <CR>')
nmap('<C-x>f', '<CMD> Telescope current_buffer_fuzzy_find <CR>', "Current buffer fuzzy find")
nmap('<C-x>j', '<CMD> Telescope jumplist <CR>', "Show jumplist")
nmap('<C-x>l', '<CMD> Telescope builtin  <CR>', "Search telescope pickers")
nmap('<C-x>b', '<CMD> Telescope buffers <CR>', "Search open buffers")
nmap('<C-x>z', ':ZenMode <CR>', "Open Zenmode")
nmap('<C-p>', ':lua require"telescope.builtin".git_files{use_git_root=false} <CR>', "Search git files")
nmap('<leader>p', ':lua require"telescope.builtin".commands() <CR>', "Search commands")

nmap('<leader>r', '<CMD> Telescope resume <CR>')
-- nmap('<C-x>j', ':cnext <CR>') Dont use quicklist as much
-- nmap('<C-x>k', ':cprev <CR>') 

-- Harpoon
nmap('<C-h>a', ':lua require("harpoon.mark").add_file() <CR>', "Harpoon: Add file")
nmap('<C-h>m', ':lua require("harpoon.ui").toggle_quick_menu() <CR>', "Harpoon: Show menu")
nmap('<C-h>n', ':lua require("harpoon.ui").nav_next() <CR>', "Harpoon: Next")
nmap('<C-h>p', ':lua require("harpoon.ui").nav_prev() <CR>', "Harpoon: Previous")


nmap('<C-f>', '<CMD> Telescope live_grep <CR>')
nmap('<leader>b', '<CMD> Telescope buffers <CR>')
nmap('<C-t>', '<CMD> Telescope lsp_dynamic_workspace_symbols <CR>')
nmap('<leader>s', '<CMD> Telescope lsp_document_symbols <CR>', "Search document symbols")
-- nmap('<C-x>t', '<CMD> Telescope tags <CR>')
-- nmap('<F8>', '<Cmd>SymbolsOutline<CR>', "Show LSP Symbols as outline")
-- nmap('<F8>', '<Cmd>Vista!!<CR>', "Show LSP Symbols as outline")
nmap('<F8>', '<Cmd>Lspsaga outline<CR>', "Show LSP Symbols as outline")
nmap('<F12>', '<Cmd> TroubleToggle <CR>', "Show Trouble window")

nmap("<A-d>", "<cmd>Lspsaga open_floaterm<CR>", "Open terminal")
tmap("<A-d>", [[<C-\><C-n><cmd>Lspsaga close_floaterm<CR>]], "Open terminal")
-- Move to previous/next
nmap('<A-,>', ':tabnext <CR>')
nmap('<A-.>', ':tabprev <CR>')
-- Goto buffer in position...
function TRC_close_win()
    if vim.bo.modifiable then
        vim.cmd('w')
    end
    vim.cmd('q')
end
nmap('<A-c>', '<CMD> lua TRC_close_win() <CR>')
-- function that closes the window and saves if it is modifiable

tmap('<Esc>', [[<C-\><C-n>]])

imap('""', '""<esc>i')
imap("''" ,"''<esc>i")
imap('((', '()<esc>i')
imap('[[', '[]<esc>i')
imap('{{','{}<esc>i')
imap('$$', '$$<esc>i')


nmap('<leader>h', ':nohls<CR>')
nmap('<leader>c', ':! ')
nmap('<C-u>', '<C-u>zz')
nmap('<C-d>','<C-d>zz')
nmap('n', 'nzz')

nmap('ø', ':vertical resize +10<CR>')
nmap('æ', ':vertical resize -10<CR>')
nmap('å', ':resize -10<CR>')
nmap('Å', ':resize +10<CR>')

-- TODO use after directory for filetype specific mappings
if (vim.bo.filetype == 'json') then
    nmap('<leader>t', 'A,<esc>o"<esc>pa":"<esc>pa"<esc>', "Add translation key")
end

nmap('<F9>', ':w <CR> :! rocaf %<CR>')
nmap('<F10>', '<cmd> NvimTreeToggle<CR>')


