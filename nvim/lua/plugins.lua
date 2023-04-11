vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
"let g:db = 'postgres://folq@localhost:5432'
let g:db = $DB_VAL
"let g:dbs = {
"\  'dev': 'postgres://folq@localhost:5432'
"\ }
let g:dbs = {
\  'val': $DB_VAL,
\ }
let g:db_ui_use_nerd_fonts = 1
let g:db_ui_auto_execute_table_helpers = 1
]])

return require('packer').startup(function(use)
    -- Packer can manage itself
    -- Infrastructure
use 'wbthomason/packer.nvim' -- Package manager
use 'lewis6991/impatient.nvim' -- Speed up startup time, maybe delete later
use 'dstein64/vim-startuptime' -- Show startup time
use 'nvim-lua/plenary.nvim' -- "All the lua functions I don't want to write twice" Needed for many plugins
use 'sbdchd/neoformat' -- Formatting
use 'lewis6991/gitsigns.nvim' -- Git signs
use 'tpope/vim-dadbod'
use 'kristijanhusak/vim-dadbod-ui'
use 'kristijanhusak/vim-dadbod-completion'
use {
  'pwntester/octo.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'kyazdani42/nvim-web-devicons',
  },
  config = function ()
    require"octo".setup()
  end
}
use {'kwakzalver/duckytype.nvim',
    config = function()
        require('duckytype').setup()
    end
}
use {'sindrets/winshift.nvim',
    config = function()
        require('winshift').setup()
    end
} -- Move windows around
use 'tpope/vim-surround' -- Surround text with quotes, brackets, etc
use 'nvim-treesitter/playground' -- Treesitter playground
--use 'nvim-treesitter/nvim-treesitter-textobjects' -- Treesitter text objects
use {"b0o/incline.nvim",
    config = function()
        require("incline").setup()
    end
} -- Floating statusline
use "nvim-pack/nvim-spectre" -- Search and replace
use({
    "glepnir/lspsaga.nvim",
    branch = "main",
    config = function()
        require('lspsaga').setup({})
    end,
})
-- use{'echasnovski/mini.nvim',
--     config = function()
--         require('mini.animate').setup({
--             cursor = {
--                 -- Whether to enable this animation
--                 enable = false,
--             },

--             -- Vertical scroll
--             scroll = {
--                 -- Whether to enable this animation
--                 enable = false,
--             },

--         })
--     end
-- }
-- use 'MunifTanjim/nui.nvim'
-- use 'rcarriga/nvim-notify'
-- use({
--   "folke/noice.nvim",
--   config = function()
--       require("noice").setup({
--           lsp = {
--               -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
--               override = {
--                   ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
--                   ["vim.lsp.util.stylize_markdown"] = true,
--                   ["cmp.entry.get_documentation"] = true,
--               },
--           },
--           -- you can enable a preset for easier configuration
--           presets = {
--               bottom_search = false, -- use a classic bottom cmdline for search
--               command_palette = true, -- position the cmdline and popupmenu together
--               long_message_to_split = true, -- long messages will be sent to a split
--               inc_rename = false, -- enables an input dialog for inc-rename.nvim
--               lsp_doc_border = false, -- add a border to hover docs and signature help
--           },
--           message = {
--               -- Noice can be used as `vim.notify` so you can route any notification like other messages
--               -- Notification messages have their level and other properties set.
--               -- event is always "notify" and kind can be any log level as a string
--               -- The default routes will forward notifications to nvim-notify
--               -- Benefit of using Noice for this is the routing and consistent history view
--               enabled = false,
--           },
--       })
--   end,
--   requires = {
--     -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
--     "MunifTanjim/nui.nvim",
--     -- OPTIONAL:
--     --   `nvim-notify` is only needed, if you want to use the notification view.
--     --   If not available, we use `mini` as the fallback
--     "rcarriga/nvim-notify",
--     }
-- })
use{'karb94/neoscroll.nvim',
    config = function()
        require('neoscroll').setup({
            mappings = {'<C-u>', '<C-d>', 'zt', 'zz', 'zb', '<C-e>', '<C-y>'},
            performance_mode = true    -- Disable "Performance Mode" on all buffers.
        })
    end,
}
use {
  'nvim-tree/nvim-tree.lua',
  config =function()
      require('nvim-tree').setup()
  end,
  requires = {
    'nvim-tree/nvim-web-devicons',
  },
  tag = 'nightly'
}
use 'github/copilot.vim' -- Copilot
use { 'TimUntersberger/neogit', -- Magit for neovim
    requires = 'nvim-lua/plenary.nvim'
}
use 'tpope/vim-fugitive' -- Git wrapper for vim
-- use 'chentoast/marks.nvim'
use 'hrsh7th/cmp-vsnip' -- Snippets for completion
use 'hrsh7th/vim-vsnip' -- Snippets for completion
use 'hrsh7th/vim-vsnip-integ' -- Snippets for completion
use 'sindrets/diffview.nvim' -- Git diffs
use {
    "folke/which-key.nvim",
    config = function()
        require("which-key").setup {}
    end
} -- Show key hints
use {
    'nvim-telescope/telescope.nvim', branch = '0.1.x',
    requires = { {'nvim-lua/plenary.nvim'} }
    } -- Telescope
use {
    'nvim-telescope/telescope-file-browser.nvim',
    config = function()
        require("telescope").load_extension "file_browser"
    end} -- File browse for telescope
use {
    'goolord/alpha-nvim',
    config = function ()
        require'alpha'.setup(require'alpha.themes.startify'.config)
    end
    } -- Better dashboard when opening neovim
use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
} -- Syntax and so much more
use {
    'ggandor/leap.nvim',
    config = function()
        require('leap').set_default_keymaps()
    end
    } -- "Neovim's answer to the mouse" Jump using 's' and two chars

use 'tpope/vim-commentary' -- Comment out blocks using "gc"
use {
    'akinsho/bufferline.nvim',
    tag = "v3.*",
    requires = 'nvim-tree/nvim-web-devicons',
    after = "catppuccin",
    config = function()
        require("bufferline").setup {
        highlights = require("catppuccin.groups.integrations.bufferline").get()
        }
    end
    }

-- use {
--     "nvim-neorg/neorg",
--     ft = "norg",
--     config = function()
--         require('neorg').setup {
--             load = {
--                 ["core.defaults"] = {}, -- Loads default behaviour
--                 ["core.norg.concealer"] = {}, -- Adds pretty icons to your documents
--                 ["core.norg.dirman"] = { -- Manages Neorg workspaces
--                     config = {
--                         workspaces = {
--                             notes = "~/notes",
--                         },
--                     },
--                 },
--             },
--         }
--     end,
--     run = ":Neorg sync-parsers",
--     requires = "nvim-lua/plenary.nvim",
-- }

-- LSP
use 'neovim/nvim-lspconfig' -- LSP
use 'hrsh7th/nvim-cmp' -- Completion plugin
use 'hrsh7th/cmp-nvim-lsp' -- LSP source for cmp
use 'hrsh7th/cmp-buffer' -- Buffer source for cmp
use 'onsails/lspkind-nvim' -- Nice icons for autocopmlete like VSCode

use { "folke/trouble.nvim", requires = "kyazdani42/nvim-web-devicons" } -- Show diagnotics in quicklist

use 'TheodorRene/skriveleif'
use 'nvim-tree/nvim-web-devicons' -- Show cool icon

-- Styling/Visuals
use 'folke/tokyonight.nvim' -- Theme
use { "catppuccin/nvim", as = "catppuccin" }
-- use 'p00f/nvim-ts-rainbow' -- Rainbow matching brackets
-- use "lukas-reineke/indent-blankline.nvim" -- Show indentline
use 'feline-nvim/feline.nvim' -- Line
use {'j-hui/fidget.nvim',
    config = function()
        require('fidget').setup()
    end
} -- Show LSP progress

-- Language specific
use{'Olical/conjure',
    ft = {'clojure'}
} -- Clojure 
use {'simrat39/rust-tools.nvim' }
end)

