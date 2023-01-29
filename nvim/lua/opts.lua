vim.o.mouse = "a"
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.cmdheight = 1
vim.o.updatetime = 50 -- update interval  (i used to use 750)
vim.o.colorcolumn = "120" -- Line length marker

vim.o.tabstop=4 -- number of spaces that a <Tab> in the file counts for
vim.o.expandtab = true -- converts tabs to spaces
vim.o.shiftwidth=4 -- number of spaces to use for each step of (auto)indent
vim.o.laststatus=3 -- always display the status line (Default is 2?)

vim.o.showmode = false -- not sure what this is for

vim.o.smartindent = true -- This might break some other indenting plugins (Treesitter)
vim.o.wrap = false -- Display long lines as just one line
vim.o.showmatch = true -- show matching brackets when text indicator is over them
-- vim.o.ignorecase = true -- Ignore case when searching
vim.o.smartcase = true -- Don't ignore case with capitals
vim.o.autoread = true -- automatically reload files when they change on disk
vim.o.clipboard = "unnamedplus" -- Copy paste between vim and everything else
vim.g.loaded_netrw = 1 -- disable netrw
vim.g.loaded_netrwPlugin = 1 -- disable netrw
vim.opt.termguicolors = true -- set term gui colors most terminals support this

-- From primeagen video
vim.opt.swapfile = false -- no swap file
vim.opt.backup = false -- no backup file
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- set undo directory
vim.opt.undofile = true -- enable persistent undo
--
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- SQLComplete stuff
-- SQLComplete is apparently bundled with Vim (IMO it shouldn't these days)
vim.g.sql_type_default = "postgresql"
vim.g.omni_sql_default_compl_type = 'syntax'

-- I dont think I need these
-- vim.o.foldmethod = "expr" 
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
vim.o.foldenable = false
vim.o.scrolloff = 8
vim.o.cursorline = true
vim.g.smoothie_no_default_mappings=true

