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
Plugin 'alvan/vim-closetag'
Plugin 'christoomey/vim-system-copy'


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
nnoremap <leader>w :w<CR>
nnoremap <leader>c :! ./mdToPdf.sh % <CR><CR>

"Language specifics
let g:markdown_enable_spell_checking = 0
let g:default_julia_version = "devel"
"
"Spellcheck commands
autocmd BufRead,BufNewFile   *.md set spell spelllang=nb,en_us
"show list of recommendation
nnoremap <leader>z z=
"add new word
nnoremap <leader>a zg
"take first word from recommendation
nnoremap <leader>x z=1<CR><CR>

"compile md to pdf
nnoremap <leader>m :! ./mdToPdf.sh % <CR><CR>
au BufRead,BufNewFile *.md setlocal textwidth=80 
nnoremap <leader>l :! latexmk -pdf % <CR><CR>




"Some standards
set number relativenumber
syntax on
set tabstop=4
set expandtab
set shiftwidth=4

"Set jk as combination for going into normal mode
inoremap jk <esc>
"For copying into system clipboard, does not work
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
