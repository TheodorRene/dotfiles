require('nvim-cursorline').setup {
  cursorline = {
    enable = true,
    timeout = 1000,
    number = false,
  },
  cursorword = {
    enable = true,
    min_length = 3,
    hl = { underline = true },
  }
}
local neogit = require('neogit')

neogit.setup {
   kind="vsplit",
   integrations = {
    diffview = false -- It crashes, but looks promising
  },
}

-- Colorscheme
vim.cmd[[colorscheme tokyonight]]

vim.cmd('autocmd TermOpen * setlocal nonumber')

vim.cmd([[
" Open pdf with same filename but with pdf extension
" Mostly used with markdown files
nnoremap <leader>o :call Open_pdf()<CR>
if !exists('*Open_pdf') 
    function Open_pdf()
        execute "!pdf " . expand('%:t:r') . ".pdf"
    endfunction
endif
]])








