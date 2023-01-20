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
use 'lewis6991/impatient.nvim' -- Speed up startup time, maybe delete later
use 'dstein64/vim-startuptime'
use 'nvim-lua/plenary.nvim' -- "All the lua functions I don't want to write twice" Needed for many plugins
use 'sbdchd/neoformat' -- Formatting
use 'lewis6991/gitsigns.nvim'
use 'sindrets/winshift.nvim'
use 'tpope/vim-surround'
use 'nvim-treesitter/playground'
use {
-- Lua
  "folke/zen-mode.nvim",
  config = function()
    require("zen-mode").setup {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
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
    'nvim-tree/nvim-web-devicons', -- optional, for file icons
  },
  tag = 'nightly' -- optional, updated every week. (see issue #1193)
}
use 'github/copilot.vim'
use({ "yioneko/nvim-yati", tag = "*", requires = "nvim-treesitter/nvim-treesitter" }) -- Yet Another Treesitter indent plugin
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
  'kdheepak/tabline.nvim',
  config = function()
    require'tabline'.setup {
      options = {
        show_tabs_only = false, -- this shows only tabs instead of tabs + buffers
      }
    }
    vim.cmd[[
      set sessionoptions+=tabpages,globals " store tabpages and globals in session (todo move to lua)
    ]]
  end,
  requires = { { 'hoob3rt/lualine.nvim', opt=true }, {'kyazdani42/nvim-web-devicons', opt = true} }
}
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

use { "folke/trouble.nvim", requires = "kyazdani42/nvim-web-devicons" } -- Show diagnotics in quicklist

use 'TheodorRene/skriveleif'
use 'nvim-tree/nvim-web-devicons' -- Show cool icon

-- Styling/Visuals
use 'folke/tokyonight.nvim' -- Theme
use 'p00f/nvim-ts-rainbow' -- Rainbow matching brackets
use "lukas-reineke/indent-blankline.nvim" -- Show indentline
use 'nvim-lualine/lualine.nvim' -- Line

-- Language specific
use{'Olical/conjure',
    ft = {'clojure'}
} -- Clojure 
use {'simrat39/rust-tools.nvim', ft = {'rust'}} -- Rust
use 'theprimeagen/harpoon' -- Jump between files

end)

