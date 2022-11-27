vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

return require('packer').startup(function(use)
    -- Packer can manage itself
    -- Infrastructure
use 'wbthomason/packer.nvim'
use 'nvim-lua/plenary.nvim' -- "All the lua functions I don't want to write twice" Needed for many plugins
use 'sbdchd/neoformat' -- Formatting
use 'github/copilot.vim'
use { 'TimUntersberger/neogit', -- Magit for neovim
    requires = 'nvim-lua/plenary.nvim'
}
use 'yamatsum/nvim-cursorline' -- Cursorline under same words as cursor
use {
    "folke/which-key.nvim",
    config = function()
        require("which-key").setup {
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        }
    end
} -- Show key hints
use "folke/twilight.nvim" -- Dim parts of the code not relevant
use {
    'nvim-telescope/telescope.nvim', tag = '0.1.0',
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

-- LSP
use 'neovim/nvim-lspconfig' -- LSP
use 'hrsh7th/nvim-cmp' -- Completion plugin
use 'hrsh7th/cmp-nvim-lsp' -- LSP source for cmp
use 'hrsh7th/cmp-buffer' -- Buffer source for cmp
use 'onsails/lspkind-nvim' -- Nice icons for autocopmlete like VSCode

use 'majutsushi/tagbar' -- Tagbar

use { "folke/trouble.nvim", requires = "kyazdani42/nvim-web-devicons" } -- Show diagnotics in quicklist

use 'TheodorRene/skriveleif'
use 'nvim-tree/nvim-web-devicons' -- Show cool icon
use {'romgrk/barbar.nvim', wants = 'nvim-web-devicons'} -- Show buffers as tabs

-- Styling/Visuals
use 'folke/tokyonight.nvim' -- Theme
use 'p00f/nvim-ts-rainbow' -- Rainbow matching brackets
use "lukas-reineke/indent-blankline.nvim" -- Show indentline
use {'nvim-lualine/lualine.nvim', config = function() require'lualine'.setup() end} -- Line

-- Language specific
use 'Olical/conjure' -- Clojure 
use 'simrat39/rust-tools.nvim' -- Rust

end)

