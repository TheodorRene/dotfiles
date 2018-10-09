set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'JuliaEditorSupport/julia-vim'
Plugin 'itchyny/lightline.vim'
Plugin 'christoomey/vim-system-copy'



" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

let g:lightline = {
      \ 'colorscheme': 'jellybeans',
      \ }

let g:default_julia_version = "devel"
let g:markdown_enable_spell_checking = 0
set number relativenumber
syntax on
set tabstop=4
set expandtab
set shiftwidth=4
inoremap jk <esc>
set clipboard=unnamedplus
colorscheme slate
set laststatus=2
set noshowmode
