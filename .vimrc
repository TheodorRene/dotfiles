set nocompatible              " be iMproved, required
filetype off                  " required


set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'itchyny/lightline.vim'
Plugin 'sheerun/vim-polyglot'
Plugin 'airblade/vim-gitgutter'
Bundle 'gabrielelana/vim-markdown'
Plugin 'justinmk/vim-sneak'
Plugin 'junegunn/goyo.vim'
Plugin 'kien/rainbow_parantheses.vim'


call vundle#end()            " required
filetype plugin indent on    " required


"Visuals
let g:lightline = {
      \ 'colorscheme': 'jellybeans',
      \ }
colorscheme slate

"Standard mappings
let mapleader =" "
nmap <leader>g :Goyo 120<CR>
nnoremap <leader>w :w<cr>
nnoremap <leader>c :! ./mdToPdf.sh % <CR><CR>

"Language specifics
let g:markdown_enable_spell_checking = 0
let g:default_julia_version = "devel"
"
"Spellcheck commands
"autocmd BufRead,BufNewFile   *.md set spell spelllang=en_us
nnoremap <leader>z z=
nnoremap <leader>a zg
nnoremap <leader>x z=1<CR><CR>


"Some standards
set number relativenumber
syntax on
set tabstop=4
set expandtab
set shiftwidth=4

"Set jk as combination for going into normal mode
inoremap jk <esc>
"For copying into system clipboard
set clipboard=unnamedplus

"No idea what these do lmao
set laststatus=2
set noshowmode
"
"Jumps between the characters for easy on the go writing
imap "" ""<esc>i
imap '' ''<esc>i
imap (( ()<esc>i
imap \[\[ \[\]<esc>i
imap {{ {}<esc>i
