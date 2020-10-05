"Great for modularity, not so much for my symlinkscript
"source $HOME/.config/nvim/config/init.vimrc
"source $HOME/.config/nvim/config/general.vimrc
"source $HOME/.config/nvim/config/keys.vimrc
"source $HOME/.config/nvim/config/line.vimrc

set nocompatible              " be iMproved, required
filetype plugin indent on                  " required
set encoding=UTF-8
set mouse=a
set splitbelow

call plug#begin()
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plug 'sheerun/vim-polyglot'
Plug 'airblade/vim-gitgutter'
Plug 'justinmk/vim-sneak'
Plug 'junegunn/goyo.vim'
Plug 'alvan/vim-closetag'
Plug 'dhruvasagar/vim-table-mode'
Plug 'unblevable/quick-scope'
Plug 'scrooloose/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'mattn/emmet-vim'
Plug 'junegunn/fzf.vim'
"Plug 'dense-analysis/ale'
Plug 'inside/vim-search-pulse'
Plug 'neoclide/coc.nvim', {'branch':'release'}
Plug 'tpope/vim-commentary'
Plug 'Yggdroot/indentline'
Plug 'gabrielelana/vim-markdown'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'skywind3000/asyncrun.vim'
Plug 'neovimhaskell/haskell-vim'
Plug 'mbbill/undotree'
Plug 'majutsushi/tagbar'

call plug#end()


"Visuals
colorscheme delek
let g:clap_theme = 'material_design_dark'

"Standard mappings
let mapleader =" "
nmap <leader>g :Goyo 120<CR>
nnoremap <leader>w :w<CR>

"Language specifics
let g:markdown_enable_spell_checking = '0'
"
" === Spellcheck commands ===
autocmd BufRead,BufNewFile   *.md setlocal spell spelllang=nb,en_us
au BufRead,BufNewFile *.md setlocal textwidth=80 
"show list of recommendation
nnoremap <leader>z z=
"add new word
nmap <leader>a zg
"take first word from recommendation
nnoremap <leader>x z=1<CR><CR>


"layout 
nnoremap <leader>v :split . <CR>
nnoremap <leader>s :vs . <CR>
nnoremap <leader>t :vs <CR> :term <CR>i
autocmd TermOpen * setlocal nonumber
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

"folding
nnoremap <leader>f :setlocal foldmethod=syntax <CR>

"Nerdtree
nmap <C-n> :NERDTreeToggle<CR>

"FZF
nmap <C-f> :Files .<CR>
nmap <C-g> :Rg<CR>
nmap <leader>b :Buffers<CR>
nmap <C-t> :Tags<CR>
nnoremap <F5> :UndotreeToggle<cr>
nmap <F8> :TagbarToggle<cr>

"let g:clap_theme = 'material_design_dark

"Some standards
set number 
syntax on
set tabstop=4
set expandtab
set shiftwidth=4

"Set jk as combination for going into normal mode
inoremap jk <esc>
tnoremap jk <C-\><C-n>

"No idea what these do lmao
set laststatus=2
set noshowmode
set showmatch
set ignorecase
set incsearch
hi Search ctermbg=LightYellow
hi Search ctermfg=Red

"
"Jumps between the characters for easy on the go writing
imap "" ""<esc>i
imap '' ''<esc>i
imap (( ()<esc>i
imap \[\[ \[\]<esc>i
imap {{ {}<esc>i
imap $$ $$<esc>i

set fillchars+=vert:│
nnoremap <leader>h :nohls<CR> 

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

"resizing windows
nmap ø :vertical resize +10<CR>
nmap æ :vertical resize -10<CR>
nmap å :resize -10<CR>
nmap Å :resize +10<CR>
nmap <leader>o :call Open_pdf()<CR>

"Prettier
"command! -nargs=0 Prettier :CocCommand prettier.formatFile
nmap <C-p> :w <CR> :! rocaf %<CR>
nmap <C-o> :w <CR>:AsyncRun -raw rocaf %<CR>
nmap <C-a> :ALEDetail<CR>
"nmap <leader>a :ALEToggle<CR>
nmap <leader>c :! 

" Ale settings
highlight ALEWarning ctermbg=DarkMagenta
nmap <C-a> :ALEDetail<CR>

" Airline config
let g:airline_powerline_fonts = 1
let g:airline_theme='minimalist'

let g:file_name = expand('%:t:r')

function Open_pdf()
    execute "!pdf " . g:file_name . ".pdf"
endfunction

source $HOME/.config/nvim/config/coc.vimrc
