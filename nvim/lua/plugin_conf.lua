-- DELETE ME
-- local augroup = vim.api.nvim_create_augroup("TablineBuffers", {})

-- function ShowCurrentBuffers()
--         local data = vim.t.tabline_data
--         if data == nil then
--                 require('tabline')._new_tab_data(vim.fn.tabpagenr())
--                 data = vim.t.tabline_data
--         end
--         data.show_all_buffers = false
--         vim.t.tabline_data = data
--         vim.cmd([[redrawtabline]])
-- end

-- vim.api.nvim_create_autocmd({ "TabEnter" }, {
--         group = augroup,
--         callback = ShowCurrentBuffers,
-- })
-- DELETE ME
--
require('gitsigns').setup{
  on_attach = function(bufnr)
      TRC_GITSIGNS_MAPPINGS(bufnr)
  end
}
require("nvim-tree").setup()
require'lualine'.setup{
    options = {
        theme = 'tokyonight'
    }
}
require'marks'.setup {
  -- whether to map keybinds or not. default true
  default_mappings = true,
  -- which builtin marks to show. default {}
  builtin_marks = { ".", "<", ">", "^" },
  mappings = {}
}

require('neogit').setup {
   kind="vsplit",
   integrations = {
    diffview = false -- It crashes, but looks promising
  },
}

local fb_actions = require "telescope".extensions.file_browser.actions
require("telescope").setup {
pickers = {
    git_files = {
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








