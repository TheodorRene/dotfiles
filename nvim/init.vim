"Great for modularity, not so much for my symlinkscript
"source $HOME/.config/nvim/config/init.vimrc
"source $HOME/.config/nvim/config/general.vimrc
"source $HOME/.config/nvim/config/keys.vimrc
"source $HOME/.config/nvim/config/line.vimrc

set nocompatible  
filetype plugin indent on   
set encoding=UTF-8
set mouse=a
set splitbelow

call plug#begin()
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-fugitive'
Plug 'justinmk/vim-sneak'
Plug 'junegunn/goyo.vim'
Plug 'alvan/vim-closetag'
Plug 'dhruvasagar/vim-table-mode'
Plug 'unblevable/quick-scope'
Plug 'scrooloose/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'mattn/emmet-vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
"Plug 'dense-analysis/ale'
Plug 'sbdchd/neoformat'
Plug 'inside/vim-search-pulse'
Plug 'neoclide/coc.nvim', {'branch':'release'}
Plug 'tpope/vim-commentary'
Plug 'Yggdroot/indentline'
"Plug 'gabrielelana/vim-markdown'
Plug 'overcache/NeoSolarized'
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'skywind3000/asyncrun.vim'
Plug 'neovimhaskell/haskell-vim'
Plug 'mbbill/undotree'
Plug 'majutsushi/tagbar'
Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }

call plug#end()

"Visuals
"colorscheme NeoSolarized
autocmd vimenter * ++nested colorscheme gruvbox
set termguicolors

"Standard mappings
let mapleader =" "
nmap <leader>g :Goyo 120<CR>
nnoremap <leader>w :w<CR>
nmap <C-i> O<Esc>
nmap <CR> o<Esc>

" === Spellcheck commands ===
let g:markdown_enable_spell_checking = '0'
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
autocmd TermOpen * setlocal nonumber "remove numbers for terminal
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap <leader>f :Neoformat<CR>

"Nerdtree
nmap <C-n> :NERDTreeToggle<CR>

"FZF
nnoremap <C-f> :Files .<CR>
nnoremap <C-g> :Rg<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <C-t> :Tags<CR>
nnoremap <F5> :UndotreeToggle<cr>
nnoremap <F8> :TagbarToggle<cr>


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
nnoremap ø :vertical resize +10<CR>
nnoremap æ :vertical resize -10<CR>
nnoremap å :resize -10<CR>
nnoremap Å :resize +10<CR>
nnoremap <leader>o :call Open_pdf()<CR>

"Prettier
"command! -nargs=0 Prettier :CocCommand prettier.formatFile
nmap <C-p> :w <CR> :! rocaf %<CR>
nmap <C-o> :w <CR>:AsyncRun -raw rocaf %<CR>
nmap <leader>c :! 
nmap <leader>n :bd <CR>

" Ale settings
highlight ALEWarning ctermbg=DarkMagenta
nmap <C-a> :ALEDetail<CR>

" Airline config
let g:airline_powerline_fonts = 1
let g:airline_theme='zenburn'


if !exists('*Open_pdf')
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif

let g:tagbar_type_elm = {
      \ 'kinds' : [
      \ 'f:function:0:0',
      \ 'm:modules:0:0',
      \ 'i:imports:1:0',
      \ 't:types:1:0',
      \ 'a:type aliases:0:0',
      \ 'c:type constructors:0:0',
      \ 'p:ports:0:0',
      \ 's:functions:0:0',
      \ ]
      \}

source $HOME/.config/nvim/config/coc.vimrc
