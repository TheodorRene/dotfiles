" autocmd BufReadPost,FileReadPost * normal zR
packadd cfilter
lua << EOF
 require'impatient'
 require'opts'
 require'plugins'
 require'plugin_conf'
 require'keybindings'
 require'lsp_conf'
 require'commands'
EOF
