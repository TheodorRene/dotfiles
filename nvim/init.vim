autocmd BufReadPost,FileReadPost * normal zR
lua << EOF
 require'impatient'.enable_profile()
 require'opts'
 require'plugins'
 require'plugin_conf'
 require'keybindings'
 require'lsp_conf'
 require'commands'
EOF
