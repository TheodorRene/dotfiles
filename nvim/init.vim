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

Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}  " Syntax highlighting
Plug 'tpope/vim-fugitive'         " Easier to do git operations in vim
" Navigation
Plug 'nvim-lua/plenary.nvim'      " Library needed for telescope
Plug 'nvim-telescope/telescope.nvim' " Seach inside file, files and filenames etc
Plug 'ggandor/lightspeed.nvim'    " easy navigation on visible lines
"
" Nice to haves
Plug 'inside/vim-search-pulse'    " Highlights line after search is finished
Plug 'tpope/vim-commentary'       " Comments out blocks of text for nearly every language
"
" IDE
Plug 'neovim/nvim-lspconfig'      " LSP
Plug 'hrsh7th/nvim-cmp'           " Autocomplete engine
Plug 'hrsh7th/cmp-nvim-lsp'       " Autocomplete source
Plug 'majutsushi/tagbar'          " Show functions in file using ctags
"
Plug 'skywind3000/asyncrun.vim'   " Run jobs async in the backgrund, used for running rocaf
" STYLING
Plug 'Yggdroot/indentline'        " Show indents
Plug 'nvim-lualine/lualine.nvim'    " statusline
Plug 'kyazdani42/nvim-web-devicons' " statusline icons
Plug 'TheodorRene/skriveleif'     " Check for spellingserrors in markdown and mutt
Plug 'Olical/conjure'             " Clojure plugin
Plug 'p00f/nvim-ts-rainbow'       " Rainbow parens
Plug 'tpope/vim-surround'         " surround

call plug#end()

"Visuals
set termguicolors
"The overlay window has some weird colors
highlight Pmenu guibg=black
"Show tabs
set list lcs=tab:\|\


"Standard mappings for leader key
let mapleader = " " 
let maplocalleader = " "

"Save buffer with space+w
nnoremap <leader>w :w<CR>
nmap <C-i> O<Esc>

" Insert newlines in normal mode
nmap <CR> o<Esc> 

"layout 
"Will possible be changed wit
nnoremap <leader>v :split . <CR>
nnoremap <leader>s :vs . <CR>
nnoremap <leader>t :vs <CR> :term <CR>i
autocmd TermOpen * setlocal nonumber "remove numbers for terminal

" Easier to jump between splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l


" Telescope
nnoremap <C-n> <cmd> Telescope file_browser <cr>
nnoremap <C-s> <cmd> Telescope current_buffer_fuzzy_find <cr>
nnoremap <C-f> <cmd> Telescope git_files<cr>
nnoremap <C-g> <cmd> Telescope live_grep<cr>
nnoremap <leader>b <cmd> Telescope buffers<cr>
nnoremap <C-t> <cmd> Telescope tags<cr>

nnoremap <F8> :TagbarToggle<cr>


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
set autoread
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


" resizing windows
nnoremap ø :vertical resize +10<CR>
nnoremap æ :vertical resize -10<CR>
nnoremap å :resize -10<CR>
nnoremap Å :resize +10<CR>

" Git 
nnoremap <A-g> :Git 
nnoremap <A-a> :Git add % <CR>
nnoremap <A-s> :Git status <CR>
nnoremap <A-d> :Git diff <CR>

" Run Rocaf https://github.com/TheodorRene/Scripts/blob/master/rocaf
nmap <C-p> :w <CR> :! rocaf %<CR>
nmap <C-o> :w <CR>:AsyncRun -raw rocaf %<CR>

" Run shell commands
nmap <leader>c :!

" Airline config
let g:airline_powerline_fonts = 1


" Open pdf with same filename but with pdf extension
" Mostly used with markdown files
nnoremap <leader>o :call Open_pdf()<CR>
if !exists('*Open_pdf') 
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif

""Lua
lua << EOF
require'lualine'.setup()

local nvim_lsp = require('lspconfig')
nvim_lsp.hls.setup{}
nvim_lsp.pyright.setup{}
nvim_lsp.clojure_lsp.setup{}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)

end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'hls', 'pyright','clojure_lsp' }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = 150,
    }
  }
end

local cmp = require 'cmp'
-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'
cmp.setup {
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
    ['<S-Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end,
  },
  sources = {
    { name = 'nvim_lsp' },
  },
}

-- Treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = "all", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  highlight = {
    enable = true,  
    additional_vim_regex_highlighting = true,
  },
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" }, list of languages you want to disable the plugin for
    extended_mode = true, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = nil, -- Do not enable for files with more than n lines, int
  },
}

EOF

