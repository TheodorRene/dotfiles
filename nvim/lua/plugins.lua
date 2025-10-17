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
    "williamboman/mason.nvim", {
        'mrcjkb/haskell-tools.nvim',
        version = '^4', -- Recommended
        lazy = false -- This plugin is already lazy
    }, -- Infrastructure
    'nvim-lua/plenary.nvim', -- "All the lua functions I don't want to write twice" Needed for many plugins

    {'nvim-telescope/telescope-fzf-native.nvim', build = 'make'},
    "marilari88/twoslash-queries.nvim", 'lewis6991/gitsigns.nvim', -- Git signs
    -- Lua
    'mbbill/undotree', -- Undo tree
    'sbdchd/neoformat', -- Formatting
    {'yorickpeterse/nvim-pqf', init = function() require('pqf').setup() end}, -- Prettier quickfix
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
    }, {'stevearc/oil.nvim', init = function() require('oil').setup() end}, {
        "epwalsh/obsidian.nvim",
        version = "*", -- recommended, use latest release instead of latest commit
        lazy = true,
        ft = "markdown",
        -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
        -- event = {
        --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
        --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
        --   -- refer to `:h file-pattern` for more examples
        --   "BufReadPre path/to/my-vault/*.md",
        --   "BufNewFile path/to/my-vault/*.md",
        -- },
        dependencies = {
            -- Required.
            "nvim-lua/plenary.nvim"

            -- see below for full list of optional dependencies 👇
        },
        opts = {
            workspaces = {
                {name = "personal", path = "~/Documents/inner-sanctum-main"}
            }

            -- see below for full list of options 👇
        }
    }, {
        "monkoose/matchparen.nvim",
        init = function() require('matchparen').setup() end
    }, --    'nvim-treesitter/playground', -- Treesitter playground,
    -- 'nvim-treesitter/nvim-treesitter-textobjects', -- Treesitter text objects
    {
        'brenoprata10/nvim-highlight-colors',
        init = function() require('nvim-highlight-colors').setup() end
    }, -- Highlight colors
    {
        "b0o/incline.nvim",
        init = function() require("incline").setup() end,
        enabled = false
    }, -- Floating statusline
    "nvim-pack/nvim-spectre", -- Search and replace
    {
        "glepnir/lspsaga.nvim",
        branch = "main",
        init = function()
            require('lspsaga').setup({lightbulb = {sign = false}})
        end
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
    }, 'github/copilot.vim', -- Copilot
    {
        'TimUntersberger/neogit', -- Magit for neovim
        dependencies = 'nvim-lua/plenary.nvim'
    }, 'tpope/vim-fugitive', -- Git wrapper for vim
    'hrsh7th/cmp-vsnip', -- Snippets for completion
    'hrsh7th/vim-vsnip', -- Snippets for completion
    'hrsh7th/vim-vsnip-integ', -- Snippets for completion
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {{"nvim-lua/plenary.nvim", branch = "master"}},
        build = "make tiktoken",
        opts = {
            -- See Configuration section for options
        }
    }, 'sindrets/diffview.nvim', -- Git diffs
    {
        "ibhagwan/fzf-lua",
        -- optional for icon support
        dependencies = {"nvim-tree/nvim-web-devicons"},
        -- or if using mini.icons/mini.nvim
        -- dependencies = { "echasnovski/mini.icons" },
        opts = {}
    }, {
        'nvim-focus/focus.nvim',
        version = false,
        init = function() require('focus').setup() end
    }, -- Focus mode
    {
        "folke/which-key.nvim",
        init = function() require("which-key").setup {} end
    }, -- Show key hints
    {
        "olimorris/codecompanion.nvim",
        opts = {},
        dependencies = {
            "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter"
        }
    }, {
        'nvim-telescope/telescope.nvim',
        version = '0.1.x',
        dependencies = 'nvim-lua/plenary.nvim'
    }, -- Telescope
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'}, -- Syntax and so much more
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
    }, 'neovim/nvim-lspconfig', -- LSP
    'hrsh7th/nvim-cmp', -- Completion plugin
    'hrsh7th/cmp-nvim-lsp', -- LSP source for cmp
    'hrsh7th/cmp-buffer', -- Buffer source for cmp
    'onsails/lspkind-nvim', -- Nice icons for autocopmlete like VSCode
    {
        "folke/trouble.nvim",
        opts = {},
        cmd = "Trouble",
        dependencies = "nvim-tree/nvim-web-devicons"
    }, -- Show diagnotics in quicklist
    'TheodorRene/skriveleif', 'nvim-tree/nvim-web-devicons', -- Show cool icon tyling/Visuals
    'folke/tokyonight.nvim', -- Theme
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = true,
        enabled = false,
        dependencies = {"nvim-tree/nvim-web-devicons"},
        config = function() require("nvim-tree").setup {} end
    }, {"catppuccin/nvim", name = "catppuccin"},
    -- 'p00f/nvim-ts-rainbow', -- Rainbow matching brackets
    -- 'freddiehaddad/feline.nvim', -- Line // DEPRECATED
    {
        'nvim-lualine/lualine.nvim',
        dependencies = {'nvim-tree/nvim-web-devicons'},
        init = function() require('lualine').setup() end
    }, {'j-hui/fidget.nvim', init = function() require('fidget').setup() end}, -- Show LSP progress anguage specific
    {'Olical/conjure', ft = {'clojure'}, branch = "main"}, -- Clojure 
    {'simrat39/rust-tools.nvim', enabled = false}, {
        'gelguy/wilder.nvim',
        init = function()
            require('wilder').setup {modes = {':', '/', '?'}}
        end
    } -- Better command line completion
})

