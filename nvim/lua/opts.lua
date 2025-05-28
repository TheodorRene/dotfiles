local opt = vim.opt
opt.mouse = "a"
opt.splitbelow = true
opt.splitright = true
opt.cmdheight = 1
opt.updatetime = 250 -- update interval  (i used to use 750)
opt.colorcolumn = "120" -- Line length marker

opt.tabstop = 4 -- number of spaces that a <Tab> in the file counts for
opt.expandtab = true -- converts tabs to spaces
opt.shiftwidth = 4 -- number of spaces to use for each step of (auto)indent
opt.laststatus = 3 -- always display the status line (Default is 2?)

opt.showmode = false -- not sure what this is for

opt.smartindent = true -- This might break some other indenting plugins (Treesitter)
opt.wrap = false -- Display long lines as just one line
opt.showmatch = true -- show matching brackets when text indicator is over them
opt.ignorecase = true -- Ignore case when searching
opt.smartcase = true -- Don't ignore case with capitals
opt.autoread = true -- automatically reload files when they change on disk
opt.breakindent = true -- This is nice for markdown files
vim.schedule(function()
    vim.opt.clipboard = 'unnamedplus' -- Copy paste between vim and everything else
end)
vim.g.loaded_netrw = 1 -- disable netrw
vim.g.loaded_netrwPlugin = 1 -- disable netrw
opt.termguicolors = true -- set term gui colors most terminals support this
opt.cdh = true -- :cd and no args changes to the home directory

-- From primeagen video
opt.swapfile = false -- no swap file
opt.backup = false -- no backup file
opt.undodir = os.getenv("HOME") .. "/.vim/undodir" -- set undo directory
opt.undofile = true -- enable persistent undo
--
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- SQLComplete stuff
-- SQLComplete is apparently bundled with Vim (IMO it shouldn't these days)
vim.g.sql_type_default = "postgresql"
vim.g.omni_sql_default_compl_type = 'syntax'
vim.opt.sessionoptions:append("localoptions") -- Save localoptions to session file
-- I dont think I need these
-- vim.o.foldmethod = "expr" 
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
-- opt.foldenable = false -- disable folding
opt.scrolloff = 8
opt.cursorline = true -- Highlight the current line
opt.listchars = "tab:▸ ,trail:·,nbsp:␣,extends:❯,precedes:❮"
opt.list = true -- Show some invisible characters (tabs...)

