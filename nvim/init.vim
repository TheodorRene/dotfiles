" autocmd BufReadPost,FileReadPost * normal zR
packadd cfilter
set timeoutlen=200
set ttimeoutlen=50
autocmd VimResized * wincmd =
lua << EOF
 require'impatient'
 require'opts'
 require'plugins'
 require'plugin_conf'
 require'keybindings'
 require'lsp_conf'
 require'commands'
EOF
