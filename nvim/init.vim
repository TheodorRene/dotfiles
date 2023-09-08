" autocmd BufReadPost,FileReadPost * normal zR
packadd cfilter
set timeoutlen=200
set ttimeoutlen=50
let g:loaded_matchparen = 1
autocmd VimResized * wincmd =
lua << EOF
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
 require'opts'
 require'plugins'
 require'plugin_conf'
 require'keybindings'
 require'lsp_conf'
 require'commands'
EOF
