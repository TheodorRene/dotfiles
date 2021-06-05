"Great for modularity, not so much for my symlinkscript
"source $HOME/.config/nvim/config/init.vimrc
"source $HOME/.config/nvim/config/general.vimrc
"source $HOME/.config/nvim/config/keys.vimrc
"source $HOME/.config/nvim/config/line.vimrc

set nocompatible  
filetype plugin indent on   
set encoding=UTF-8
set mouse=a                       " Use mouse
set splitbelow                    " Set default split
set clipboard=unnamedplus

call plug#begin()

" Syntax highlighting
Plug 'sheerun/vim-polyglot'       " Syntax for most languages
Plug 'neovimhaskell/haskell-vim'  " Syntax for haskell
" Git
Plug 'tpope/vim-fugitive'         " Easier to do git operations in vim
" Navigation
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'           " Fuzzy finder
Plug 'justinmk/vim-sneak'         " 2-gram seach basically
Plug 'unblevable/quick-scope'     " Highlights fastest way to get to word in line using 'f'
Plug 'scrooloose/nerdtree'        " File explorer
Plug 'ryanoasis/vim-devicons'     " Nice icons for nerdtree
" Nice to haves
Plug 'alvan/vim-closetag'         " Autoclose HTML tags
Plug 'dhruvasagar/vim-table-mode' " Make nice tables in vim
Plug 'inside/vim-search-pulse'    " Highlights line when press enter after search
Plug 'tpope/vim-commentary'       " Comments out blocks of text for nearly every language
" IDE
Plug 'sbdchd/neoformat'           " Formatting
Plug 'neoclide/coc.nvim', {'branch':'release'} " Conquerer of Completion
Plug 'skywind3000/asyncrun.vim'   " Run jobs async in the backgrund, used for running rocaf
Plug 'majutsushi/tagbar'          " Show functions in file using ctags
" STYLING
Plug 'Yggdroot/indentline'        " Show indents
Plug 'morhetz/gruvbox'            " Gruvbox theme
Plug 'vim-airline/vim-airline'    " Give 'toolbar'  on the bottom
Plug 'vim-airline/vim-airline-themes' "themes
Plug 'TheodorRene/skriveleif'     " Check for spellingserrors in markdown and mutt

call plug#end()

"Visuals
autocmd vimenter * ++nested colorscheme gruvbox
set termguicolors

"Standard mappings
let mapleader =" " 
nnoremap <leader>w :w<CR>
nmap <C-i> O<Esc>
nmap <CR> o<Esc>

" === Spellcheck commands ===
let g:markdown_enable_spell_checking = '0'
"autocmd BufRead,BufNewFile   *.md setlocal spell spelllang=nb,en_us
"au BufRead,BufNewFile *.md setlocal textwidth=80 
""show list of recommendation
"nnoremap <leader>z z=
""add new word
"nmap <leader>a zg
""take first word from recommendation
"nnoremap <leader>x z=1<CR><CR>
" Do not conceal syntax
let g:vim_json_syntax_conceal = 0
let g:vim_markdown_conceal = 0
let g:vim_markdown_conceal_code_blocks = 0
" ==========================


"layout 
nnoremap <leader>v :split . <CR>
nnoremap <leader>s :vs . <CR>
nnoremap <leader>t :vs <CR> :term <CR>i
autocmd TermOpen * setlocal nonumber "remove numbers for terminal

" Easier to jump between splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Format file
nnoremap <leader>f :Neoformat<CR>

"Nerdtree
nmap <C-n> :NERDTreeToggle<CR>

"FZF
nnoremap <C-f> :GitFiles .<CR>
nnoremap <C-g> :Rg<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <C-t> :Tags<CR>
nnoremap <F8> :TagbarToggle<cr>
let g:fzf_history_dir = '~/.local/share/fzf-history'


"Some standards
"set number 
syntax on
set tabstop=4
set expandtab
set shiftwidth=4

"Set jk as combination for going into normal mode
inoremap jk <esc>
tnoremap jk <C-\><C-n>

"Dont remember idea what these do lmao
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

" Set char split between panes
set fillchars+=vert:│

" Remove highlighting after a search (so annoying)
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

" resizing windows
nnoremap ø :vertical resize +10<CR>
nnoremap æ :vertical resize -10<CR>
nnoremap å :resize -10<CR>
nnoremap Å :resize +10<CR>

" Run Rocaf https://github.com/TheodorRene/Scripts/blob/master/rocaf
nmap <C-p> :w <CR> :! rocaf %<CR>
nmap <C-o> :w <CR>:AsyncRun -raw rocaf %<CR>

" Run shell commands
nmap <leader>c :!

" Airline config
let g:airline_powerline_fonts = 1
let g:airline_theme='zenburn'


" Open pdf with same filename but with pdf extension
" Mostly used with markdown files
nnoremap <leader>o :call Open_pdf()<CR>
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
