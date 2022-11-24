function imap(comb, cmd)
	vim.api.nvim_set_keymap('i', comb, cmd, {noremap = true, silent = true})
end

function nmap(comb, cmd)
	vim.api.nvim_set_keymap('n', comb, cmd, {noremap = true, silent = true})
end

function tmap(comb, cmd)
	vim.api.nvim_set_keymap('t', comb, cmd, {noremap = true, silent = true})
end


imap('jk', '<esc>')

opt = vim.opt

opt.encoding = "UTF-8"
opt.mouse = "a"
opt.splitbelow = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "

nmap('<Leader>w',':w<CR>')
nmap('<Leader>v', ':split . <CR>')
nmap('<Leader>s', ':vsplit . <CR>')

nmap('<C-i>', 'O<Esc>')

nmap('<CR>', 'o<Esc>')

vim.cmd('autocmd TermOpen * setlocal nonumber')

nmap('<C-h>', '<C-w>h')
nmap('<C-j>', '<C-w>j')
nmap('<C-k>', '<C-w>k')
nmap('<C-l>', '<C-w>l')

nmap('<C-n>', '<CMD> Telescope file_browser <CR>')
nmap('<C-s>', '<CMD> Telescope current_buffer_fuzzy_find <CR>')
nmap('<C-p>', '<CMD> Telescope git_files <CR>')
nmap('<C-g>', '<CMD> Telescope live_grep <CR>')
nmap('<leader>b', '<CMD> Telescope buffers <CR>')
nmap('<C-t>', '<CMD> Telescope tags <CR>')

nmap('<F8>', ':TagbarToggle<CR>')

vim.cmd([[
syntax on
set tabstop=4
set expandtab
set shiftwidth=4
"Dont remember idea what these do lmao
set laststatus=2
set noshowmode
set showmatch
set ignorecase
set incsearch
set autoread
hi Search ctermbg=LightYellow
hi Search ctermfg=Red
set fillchars+=vert:│
" Airline config
let g:airline_powerline_fonts = 1
tnoremap jk <C-\><C-n>
let g:prettier#autoformat_require_pragma = 0
let g:prettier#exec_cmd_async = 1
let g:prettier#config#tab_width = '2'

" Open pdf with same filename but with pdf extension
" Mostly used with markdown files
nnoremap <leader>o :call Open_pdf()<CR>
if !exists('*Open_pdf') 
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif

" Git 
nnoremap <A-g> :Git 
nnoremap <A-a> :Git add % <CR>
nnoremap <A-s> :Git status <CR>
nnoremap <A-d> :Git diff <CR>
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

