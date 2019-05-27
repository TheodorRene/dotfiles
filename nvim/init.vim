"Great for modularity, not so much for my symlinkscript
"source $HOME/.config/nvim/config/init.vimrc
"source $HOME/.config/nvim/config/general.vimrc
"source $HOME/.config/nvim/config/plugins.vimrc
"source $HOME/.config/nvim/config/keys.vimrc
"source $HOME/.config/nvim/config/line.vimrc

set nocompatible              " be iMproved, required
filetype off                  " required
set encoding=UTF-8

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
Plugin 'vim-perl/vim-perl', { 'for': 'perl', 'do': 'make clean carp dancer highlight-all-pragmas moose test-more try-tiny' }
Plugin 'dhruvasagar/vim-table-mode'
Plugin 'unblevable/quick-scope'
Plugin 'scrooloose/nerdtree'
Plugin 'ryanoasis/vim-devicons'
Plugin 'mattn/emmet-vim'
Plugin 'junegunn/fzf.vim'
Plugin 'neoclide/coc.nvim', {'tag': '*', 'do': './install.sh'}



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
nmap <leader>a zg
"take first word from recommendation
nnoremap <leader>x z=1<CR><CR>

"compile md to pdf
nnoremap <leader>m :! ./mdToPdf.sh % <CR><CR>
au BufRead,BufNewFile *.md setlocal textwidth=80 
nnoremap <leader>l :! latexmk -pdf % <CR><CR>

"layout 
nnoremap <leader>v :split . <CR>
nnoremap <leader>s :vs . <CR>

"folding
nnoremap <leader>f :setlocal foldmethod=syntax <CR>

"Nerdtree
map <C-n> :NERDTreeToggle<CR>
map <C-u> :Files .<CR>

"Some standards
set number relativenumber
syntax on
set tabstop=4
set expandtab
set shiftwidth=4

"Set jk as combination for going into normal mode
inoremap jk <esc>

"No idea what these do lmao
set laststatus=2
set noshowmode
set showmatch
set ignorecase
set incsearch
"
"Jumps between the characters for easy on the go writing
imap "" ""<esc>i
imap '' ''<esc>i
imap (( ()<esc>i
imap \[\[ \[\]<esc>i
imap {{ {}<esc>i

set fillchars+=vert:│

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

"coc autocomplete
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
set hidden
" Better display for messages
set cmdheight=2

autocmd FileType markdown let b:coc_suggest_disable = 1

"resizing windows
nmap ø :vertical resize +10<CR>
nmap æ :vertical resize -10<CR>
nmap å :resize -10<CR>
nmap Å :resize +10<CR>




