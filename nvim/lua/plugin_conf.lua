require('gitsigns').setup{
  on_attach = function(bufnr)
      TRC_GITSIGNS_MAPPINGS(bufnr)
  end
}
require('winshift').setup()
require("nvim-tree").setup()
require'lualine'.setup{
    options = {
        theme = 'tokyonight'
    }
}

require('neogit').setup {
   -- kind="vsplit",
   integrations = {
    diffview = true -- It crashes, but looks promising
  },
}

local fb_actions = require "telescope".extensions.file_browser.actions
require("telescope").setup {
pickers = {
    git_files = {
      theme = "dropdown",
      previewer = false,
    },
    buffers = {
      theme = "dropdown",
      previewer = false,
    },
    find_files = {
      theme = "dropdown",
      previewer = false,
    },
},

  extensions = {
    file_browser = {
      theme = "ivy",
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        ["i"] = {
          ["<C-e>"] = fb_actions.create,
          ["<C-r>"] = fb_actions.rename
        },
      },
    },
  },
}

require("telescope").load_extension "file_browser"
-- Treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = "all",
  highlight = {
    enable = true,
  },
  rainbow = {
    enable = true,
    extended_mode = true,
    max_file_lines = nil,
  },
  indent = {
      enable = false
  },
  additional_vim_regex_highlighting = false,
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








