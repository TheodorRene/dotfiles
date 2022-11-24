function imap(comb, cmd)
	vim.api.nvim_set_keymap('i', comb, cmd, {noremap = true, silent = true})
end

function nmap(comb, cmd)
	vim.api.nvim_set_keymap('n', comb, cmd, {noremap = true, silent = true})
end

function tmap(comb, cmd)
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

-- Colorscheme
vim.cmd[[colorscheme tokyonight]]
require'shade'.setup({
  overlay_opacity = 50,
  opacity_step = 1,
  keys = {
    brightness_up    = '<C-Up>',
    brightness_down  = '<C-Down>',
    toggle           = '<Leader>s',
  }
})

imap('jk', '<esc>')

opt = vim.opt

opt.encoding = "UTF-8"
opt.mouse = "a"
opt.splitbelow = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "

nmap('<Leader>w',':w<CR>')
nmap('<M-v>', ':split . <CR>')
nmap('<M-s>', ':vsplit . <CR>')

nmap('<C-i>', 'O<Esc>')

nmap('<CR>', 'o<Esc>')

vim.cmd('autocmd TermOpen * setlocal nonumber')

nmap('<M-h>', '<C-w>h')
nmap('<M-j>', '<C-w>j')
nmap('<M-k>', '<C-w>k')
nmap('<M-l>', '<C-w>l')
nmap('<M-q>', ':bn <CR>')
nmap('<M-w>', ':bp <CR>')

nmap('<C-n>', '<CMD> Telescope file_browser <CR>')
nmap('/', '<CMD> Telescope current_buffer_fuzzy_find <CR>')
nmap('<C-p>', ':lua require"telescope.builtin".git_files{use_git_root=false} <CR>')
nmap('<leader>p', ':lua require"telescope.builtin".commands{} <CR> <CR>')


nmap('<C-f>', '<CMD> Telescope live_grep <CR>')
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
nnoremap <A-t> :Git status <CR>
nnoremap <A-d> :Git diff --no-ext-diff <CR>

"Buffer
" Move to previous/next
nnoremap <silent>    <A-,> <Cmd>BufferPrevious<CR>
nnoremap <silent>    <A-.> <Cmd>BufferNext<CR>
" Re-order to previous/next
nnoremap <silent>    <A-<> <Cmd>BufferMovePrevious<CR>
nnoremap <silent>    <A->> <Cmd>BufferMoveNext<CR>
" Goto buffer in position...
nnoremap <silent>    <A-1> <Cmd>BufferGoto 1<CR>
nnoremap <silent>    <A-2> <Cmd>BufferGoto 2<CR>
nnoremap <silent>    <A-3> <Cmd>BufferGoto 3<CR>
nnoremap <silent>    <A-4> <Cmd>BufferGoto 4<CR>
nnoremap <silent>    <A-5> <Cmd>BufferGoto 5<CR>
nnoremap <silent>    <A-6> <Cmd>BufferGoto 6<CR>
nnoremap <silent>    <A-7> <Cmd>BufferGoto 7<CR>
nnoremap <silent>    <A-8> <Cmd>BufferGoto 8<CR>
nnoremap <silent>    <A-9> <Cmd>BufferGoto 9<CR>
nnoremap <silent>    <A-0> <Cmd>BufferLast<CR>
" Pin/unpin buffer
nnoremap <silent>    <A-p> <Cmd>BufferPin<CR>
" Close buffer
nnoremap <silent>    <A-c> <Cmd>BufferClose<CR>
" Wipeout buffer
"                          :BufferWipeout
" Close commands
"                          :BufferCloseAllButCurrent
"                          :BufferCloseAllButVisible
"                          :BufferCloseAllButPinned
"                          :BufferCloseAllButCurrentOrPinned
"                          :BufferCloseBuffersLeft
"                          :BufferCloseBuffersRight
" Magic buffer-picking mode
" nnoremap <silent> <C-p>    <Cmd>BufferPick<CR>
" Sort automatically by...
nnoremap <silent> <Space>bb <Cmd>BufferOrderByBufferNumber<CR>
nnoremap <silent> <Space>bd <Cmd>BufferOrderByDirectory<CR>
nnoremap <silent> <Space>bl <Cmd>BufferOrderByLanguage<CR>
nnoremap <silent> <Space>bw <Cmd>BufferOrderByWindowNumber<CR>

" Other:
" :BarbarEnable - enables barbar (enabled by default)
" :BarbarDisable - very bad command, should never be used
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

