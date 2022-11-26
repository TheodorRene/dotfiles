local function imap(comb, cmd)
	vim.api.nvim_set_keymap('i', comb, cmd, {noremap = true, silent = true})
end

local function nmap(comb, cmd)
	vim.api.nvim_set_keymap('n', comb, cmd, {noremap = true, silent = true})
end

local function tmap(comb, cmd)
	vim.api.nvim_set_keymap('t', comb, cmd, {noremap = true, silent = true})
end
require('nvim-cursorline').setup {
  cursorline = {
    enable = true,
    timeout = 1000,
    number = false,
  },
  cursorword = {
    enable = true,
    min_length = 3,
    hl = { underline = true },
  }
}
local neogit = require('neogit')

neogit.setup {
   kind="vsplit",
   integrations = {
    diffview = false -- It crashes, but looks promising
  },
}

-- Colorscheme
vim.cmd[[colorscheme tokyonight]]
imap('jk', '<esc>')


vim.g.mapleader = " "
vim.g.maplocalleader = " "

nmap('<Leader>w',':w<CR>')
nmap('<M-v>', ':split <CR>')
nmap('<M-s>', ':vsplit <CR>')

nmap('<C-i>', 'O<Esc>')

vim.cmd('autocmd TermOpen * setlocal nonumber')

nmap('<M-h>', '<C-w>h')
nmap('<M-j>', '<C-w>j')
nmap('<M-k>', '<C-w>k')
nmap('<M-l>', '<C-w>l')
nmap('<M-q>', ':bn <CR>')
nmap('<M-w>', ':bp <CR>')

nmap('<C-n>', '<CMD> Telescope file_browser <CR>')
-- nmap('/', '<CMD> Telescope current_buffer_fuzzy_find <CR>')
nmap('<C-x>f', '<CMD> Telescope current_buffer_fuzzy_find <CR>')
nmap('<C-p>', ':lua require"telescope.builtin".git_files{use_git_root=false} <CR>')
nmap('<leader>p', ':lua require"telescope.builtin".commands() <CR>')
-- nmap('<C-x>j', ':cnext <CR>') Dont use quicklist as much
-- nmap('<C-x>k', ':cprev <CR>') 


nmap('<C-f>', '<CMD> Telescope live_grep <CR>')
nmap('<leader>b', '<CMD> Telescope buffers <CR>')
nmap('<C-t>', '<CMD> Telescope treesitter <CR>')
nmap('<C-x>t', '<CMD> Telescope tags <CR>')
nmap('<C-g>c', '<CMD> Telescope git_commits <CR>')
nmap('<C-g>f', '<CMD> Telescope git_bcommits <CR>')
nmap('<C-g>b', '<CMD> Telescope git_branches <CR>')
nmap('<C-g>h', '<CMD> Telescope git_stash <CR>')
nmap('<C-g>s', '<CMD> Telescope git_status <CR>')
nmap('<C-g>l', '<CMD> Telescope builtin  <CR>')

nmap('<A-g>', ':Neogit <CR>')
nmap('<F8>', ':TagbarToggle<CR>')

-- Move to previous/next
nmap('<A-,>', '<Cmd>BufferPrevious<CR>')
nmap('<A-.>', '<Cmd>BufferNext<CR>')
-- Rer to previous/next
nmap('<A-<>', '<Cmd>BufferMovePrevious<CR>')
nmap('<A->>', '<Cmd>BufferMoveNext<CR>')
-- Goto buffer in position...
nmap( '<A-1>', '<Cmd>BufferGoto 1<CR>')
nmap( '<A-2>', '<Cmd>BufferGoto 2<CR>')
nmap( '<A-3>', '<Cmd>BufferGoto 3<CR>')
nmap( '<A-4>', '<Cmd>BufferGoto 4<CR>')
nmap( '<A-5>', '<Cmd>BufferGoto 5<CR>')
nmap( '<A-6>', '<Cmd>BufferGoto 6<CR>')
nmap( '<A-7>', '<Cmd>BufferGoto 7<CR>')
nmap( '<A-8>', '<Cmd>BufferGoto 8<CR>')
nmap( '<A-9>', '<Cmd>BufferGoto 9<CR>')
nmap( '<A-0>', '<Cmd>BufferLast<CR>')
-- Pipin buffer
nmap( '<A-p>', '<Cmd>BufferPin<CR>')
-- Clbuffer
nmap( '<A-c>', '<Cmd>BufferClose<CR>')
nmap('<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>')
nmap('<Space>bd', '<Cmd>BufferOrderByDirectory<CR>')
nmap('<Space>bl', '<Cmd>BufferOrderByLanguage<CR>')
nmap('<Space>bw', '<Cmd>BufferOrderByWindowNumber<CR>')
tmap('jk', [[<C-\><C-n>]])

-- Other:
-- :BarbarEnable - enables barbar (enabled by default)
-- :BarbarDisable - very bad command, should never be used

vim.cmd([[
" Open pdf with same filename but with pdf extension
" Mostly used with markdown files
nnoremap <leader>o :call Open_pdf()<CR>
if !exists('*Open_pdf') 
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif
]])


imap('""', '""<esc>i')
imap("''" ,"''<esc>i")
imap('((', '()<esc>i')
imap('[[', '[]<esc>i')
imap('{{','{}<esc>i')
imap('$$', '$$<esc>i')


nmap('<leader>h', ':nohls<CR>')

nmap('ø', ':vertical resize +10<CR>')
nmap('æ', ':vertical resize -10<CR>')
nmap('å', ':resize -10<CR>')
nmap('Å', ':resize -10<CR>')

nmap('<C-o>', ':w <CR> :! rocaf %<CR>')

nmap('<leader>c', ':!')

