vim.cmd([[
"let g:db = 'postgres://folq@localhoste5432'
let g:db = $DB_VAL_LOCAL
"let g:dbs = {
"\  'dev': 'postgres://folq@localhost:5432'
"\ }
let g:dbs = {
\  'val': $DB_VAL,
\  'val-local': $DB_VAL_LOCAL,
\ }
let g:db_ui_use_nerd_fonts = 1
let g:db_ui_auto_execute_table_helpers = 1
let g:vim_matchtag_enable_by_default = 1
let g:vim_matchtag_files = '*.html,*.xml,*.js,*.jsx,*.vue,*.svelte,*.jsp,*.tsx'
let g:vim_matchtag_highlight_cursor_on = 1
]])

require('lazy').setup({

    -- Mason
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    -- Infrastructure
    'xiyaowong/transparent.nvim', 'nvim-lua/plenary.nvim', -- "All the lua functions I don't want to write twice" Needed for many plugins

    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    'sbdchd/neoformat', -- Formatting
    'lewis6991/gitsigns.nvim', -- Git signs
    -- Lua
    'mbbill/undotree', -- Undo tree
    'sbdchd/neoformat', -- Formatting
    { 'yorickpeterse/nvim-pqf', init = function() require('pqf').setup() end }, -- Prettier quickfix
    'mattkubej/jest.nvim', 'HiPhish/rainbow-delimiters.nvim', {
        "folke/flash.nvim",
        event = "VeryLazy",
        ---@type Flash.Config
        opts = {},
        -- stylua: ignore
        keys = {
            {
                "s",
                mode = {"n", "x", "o"},
                function() require("flash").jump() end,
                desc = "Flash"
            }, {
                "S",
                mode = {"n", "x", "o"},
                function() require("flash").treesitter() end,
                desc = "Flash Treesitter"
            }
        }
    }, {'stevearc/oil.nvim', init = function() require('oil').setup() end},
   -- 'tpope/vim-dadbod', 
   -- 'kristijanhusak/vim-dadbod-ui', 
   -- 'kristijanhusak/vim-dadbod-completion', 
   {
        "monkoose/matchparen.nvim",
        init = function() require('matchparen').setup() end
    }, {"lukas-reineke/indent-blankline.nvim"}, {
        'natecraddock/workspaces.nvim',
        init = function()
            require('workspaces').setup({hooks = {open = {"Alpha"}}})
        end
    }, -- 'leafOfTree/vim-matchtag',
 {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  opts = {
    -- add any opts here
  },
  keys = {
    { "<leader>aa", function() require("avante.api").ask() end, desc = "avante: ask", mode = { "n", "v" } },
    { "<leader>ar", function() require("avante.api").refresh() end, desc = "avante: refresh" },
    { "<leader>ae", function() require("avante.api").edit() end, desc = "avante: edit", mode = "v" },
  },
  dependencies = {
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to setup it properly if you have lazy=true
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}, {
        'sindrets/winshift.nvim',
        init = function() require('winshift').setup() end
    }, -- Move windows around
    --    'nvim-treesitter/playground', -- Treesitter playground,
    -- 'nvim-treesitter/nvim-treesitter-textobjects', -- Treesitter text objects
    { 'brenoprata10/nvim-highlight-colors', init = function() require('nvim-highlight-colors').setup() end }, -- Highlight colors
    {"b0o/incline.nvim", init = function() require("incline").setup() end}, -- Floating statusline
    "nvim-pack/nvim-spectre", -- Search and replace
    {
        "glepnir/lspsaga.nvim",
        branch = "main",
        init = function() require('lspsaga').setup({
            lightbulb = {sign = false},
        }) end
    }, {
        'karb94/neoscroll.nvim',
        init = function()
            require('neoscroll').setup({
                mappings = {
                    '<C-u>', '<C-d>', 'zt', 'zz', 'zb', '<C-e>', '<C-y>'
                },
                performance_mode = true -- Disable "Performance Mode" on all buffers.
            })
        end
    },
    'github/copilot.vim', -- Copilot
    {
        'TimUntersberger/neogit', -- Magit for neovim
        dependencies = 'nvim-lua/plenary.nvim'
    }, 'tpope/vim-fugitive', -- Git wrapper for vim
    'hrsh7th/cmp-vsnip', -- Snippets for completion
    'hrsh7th/vim-vsnip', -- Snippets for completion
    'hrsh7th/vim-vsnip-integ', -- Snippets for completion
    'sindrets/diffview.nvim', -- Git diffs
    {
        "folke/which-key.nvim",
        init = function() require("which-key").setup {} end
    }, -- Show key hints
    {
        'nvim-telescope/telescope.nvim',
        version = '0.1.x',
        dependencies = 'nvim-lua/plenary.nvim'
    }, -- Telescope
    {
        'goolord/alpha-nvim',
        init = function()
            require'alpha'.setup(require'alpha.themes.startify'.config)
        end
    }, -- Better dashboard when opening neovim
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'}, -- Syntax and so much more
    -- {
    --     'ggandor/leap.nvim',
    --     init = function() require('leap').set_default_keymaps() end
    -- }, -- "Neovim's answer to the mouse" Jump using 's' and two chars
    -- 'tpope/vim-commentary', -- Comment out blocks using "gc"
    {
        'akinsho/bufferline.nvim',
        version = "v4.*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        init = function()
            require("bufferline").setup {
                highlights = require("catppuccin.groups.integrations.bufferline").get()
            }
        end
    }, 'neovim/nvim-lspconfig', -- LSP
    'hrsh7th/nvim-cmp', -- Completion plugin
    'hrsh7th/cmp-nvim-lsp', -- LSP source for cmp
    'hrsh7th/cmp-buffer', -- Buffer source for cmp
    'onsails/lspkind-nvim', -- Nice icons for autocopmlete like VSCode
    {"folke/trouble.nvim", dependencies = "nvim-tree/nvim-web-devicons"}, -- Show diagnotics in quicklist
    'TheodorRene/skriveleif', 'nvim-tree/nvim-web-devicons', -- Show cool icon tyling/Visuals
    'folke/tokyonight.nvim', -- Theme
    {
      "nvim-tree/nvim-tree.lua",
      version = "*",
      lazy = false,
      dependencies = {
        "nvim-tree/nvim-web-devicons",
      },
      config = function()
        require("nvim-tree").setup {}
      end,
    },
    {"catppuccin/nvim", name = "catppuccin"},
    -- 'p00f/nvim-ts-rainbow', -- Rainbow matching brackets
    -- 'freddiehaddad/feline.nvim', -- Line // DEPRECATED
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        init = function() require('lualine').setup() end
    },
    {
        'j-hui/fidget.nvim',
        init = function() require('fidget').setup() end
    }, -- Show LSP progress anguage specific
    {'Olical/conjure', ft = {'clojure'}}, -- Clojure 
    'simrat39/rust-tools.nvim', {
        'gelguy/wilder.nvim',
        init = function()
            require('wilder').setup {modes = {':', '/', '?'}}
        end
    } -- Better command line completion
})

