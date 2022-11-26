let g:prettier#autoformat_require_pragma = 0
let g:prettier#exec_cmd_async = 1
set clipboard=unnamedplus
nnoremap <C-u> <C-u>zz
nnoremap <C-d> <C-d>zz
nnoremap <C-e> <C-e>M
nnoremap <C-y> <C-y>M
nnoremap n nzz
lua << EOF
require('myconfig')
require('plugins')
require('oldlua')
require'opts'
EOF
