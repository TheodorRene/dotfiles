vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
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
use 'sindrets/winshift.nvim' -- Move windows around
use 'tpope/vim-surround' -- Surround text with quotes, brackets, etc
use 'nvim-treesitter/playground' -- Treesitter playground
use 'nvim-treesitter/nvim-treesitter-textobjects' -- Treesitter text objects
use "b0o/incline.nvim" -- Floating statusline
use "nvim-pack/nvim-spectre" -- Search and replace
use {
-- Lua
  "folke/zen-mode.nvim",
  config = function()
    require("zen-mode").setup()
  end
}
use({
    "glepnir/lspsaga.nvim",
    branch = "main",
    config = function()
        require('lspsaga').setup({})
    end,
})
use{'karb94/neoscroll.nvim',
    config = function()
        require('neoscroll').setup({
            mappings = {'<C-u>', '<C-d>', 'zt', 'zz', 'zb', '<C-e>', '<C-y>'}
        })
    end,
}
use {
  'nvim-tree/nvim-tree.lua',
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
-- use{'theodorrene/diffview.nvim', branch = 'warn-if-big-diff'}
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

use {
    "nvim-neorg/neorg",
    ft = "norg",
    config = function()
        require('neorg').setup {
            load = {
                ["core.defaults"] = {}, -- Loads default behaviour
                ["core.norg.concealer"] = {}, -- Adds pretty icons to your documents
                ["core.norg.dirman"] = { -- Manages Neorg workspaces
                    config = {
                        workspaces = {
                            notes = "~/notes",
                        },
                    },
                },
            },
        }
    end,
    run = ":Neorg sync-parsers",
    requires = "nvim-lua/plenary.nvim",
}

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
use 'p00f/nvim-ts-rainbow' -- Rainbow matching brackets
use "lukas-reineke/indent-blankline.nvim" -- Show indentline
use 'feline-nvim/feline.nvim' -- Line
use 'j-hui/fidget.nvim'

-- Language specific
use{'Olical/conjure',
    ft = {'clojure'}
} -- Clojure 
use {'simrat39/rust-tools.nvim', ft = {'rust'}} -- Rust
use 'theprimeagen/harpoon' -- Jump between files

end)

