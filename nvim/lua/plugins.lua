V.cmd([[
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
  use 'sbdchd/neoformat'
  use { 'TimUntersberger/neogit',
    requires = 'nvim-lua/plenary.nvim'
  }
  use 'yamatsum/nvim-cursorline'
  use {
    "folke/which-key.nvim",
    config = function()
      require("which-key").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end
  }
 -- Lua
  use {
    "folke/twilight.nvim",
    config = function()
      require("twilight").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end
  }
  use {
  'nvim-telescope/telescope.nvim', tag = '0.1.0',
  requires = { {'nvim-lua/plenary.nvim'} }
  }
  use 'nvim-telescope/telescope-file-browser.nvim'
  use {
      'goolord/alpha-nvim',
      config = function ()
          require'alpha'.setup(require'alpha.themes.startify'.config)
      end
  }
  --use 'nvim-treesitter/playground' 
  use {
	'nvim-treesitter/nvim-treesitter',
	run = ':TSUpdate'
  }
  use 'ggandor/leap.nvim'
  use 'inside/vim-search-pulse'
  use 'tpope/vim-commentary'
  use 'prettier/vim-prettier'

  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-buffer'
  use 'onsails/lspkind-nvim'
  use 'majutsushi/tagbar'
  use 'simrat39/rust-tools.nvim'
  use {
  "folke/trouble.nvim",
  requires = "kyazdani42/nvim-web-devicons",
  config = function()
    require("trouble").setup {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  end
}

  use 'Olical/conjure'
  use 'TheodorRene/skriveleif'
  use 'Yggdroot/indentline'
  use 'nvim-tree/nvim-web-devicons'
  use {'romgrk/barbar.nvim', wants = 'nvim-web-devicons'}
  use 'nvim-lualine/lualine.nvim'
  use 'folke/tokyonight.nvim'
  use 'p00f/nvim-ts-rainbow'

end)

