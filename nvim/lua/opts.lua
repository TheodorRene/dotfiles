vim.o.encoding = "UTF-8"
vim.o.mouse = "a"
vim.o.splitbelow = true
vim.o.cmdheight = 1
vim.o.updatetime = 750
vim.o.colorcolumn = "120"
vim.o.tabstop=4
vim.o.expandtab = true
vim.o.shiftwidth=4
vim.o.laststatus=2
vim.o.showmode = false
vim.o.showmatch = true
vim.o.ignorecase = true
vim.o.incsearch = true
vim.o.autoread = true
vim.o.clipboard = "unnamedplus"
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- SQLComplete stuff
-- SQLComplete is apparently bundled with Vim (IMO it shouldn't these days)
vim.g.sql_type_default = "postgresql"
vim.g.omni_sql_default_compl_type = 'syntax'
