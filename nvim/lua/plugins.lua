vim.cmd([[
  "augroup packer_user_config
  "  autocmd!
    "autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  "augroup end
"let g:db = 'postgres://folq@localhost:5432'
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

    -- Packer can manage itself
    -- Infrastructure
    'xiyaowong/transparent.nvim', 'lewis6991/impatient.nvim', -- Speed up startup time, maybe delete later
    'dstein64/vim-startuptime', -- Show startup time
    'nvim-lua/plenary.nvim', -- "All the lua functions I don't want to write twice" Needed for many plugins
    'sbdchd/neoformat', -- Formatting
    'lewis6991/gitsigns.nvim', -- Git signs
    'tpope/vim-dadbod', 'mbbill/undotree', -- Undo tree
    {'stevearc/oil.nvim', init = function() require('oil').setup() end},
    'kristijanhusak/vim-dadbod-ui', 'kristijanhusak/vim-dadbod-completion', {
        "lukas-reineke/indent-blankline.nvim",
        init = function() require('indent_blankline').setup() end
    }, {
        'natecraddock/workspaces.nvim',
        init = function()
            require('workspaces').setup({hooks = {open = {"Alpha"}}})
        end
    }, -- 'leafOfTree/vim-matchtag',
    'rhysd/clever-f.vim', {
        'pwntester/octo.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim',
            'nvim-tree/nvim-web-devicons'
        },
        init = function() require"octo".setup() end
    }, 'Marskey/telescope-sg', {
        'kwakzalver/duckytype.nvim',
        init = function() require('duckytype').setup() end
    },
    {
        'sindrets/winshift.nvim',
        init = function() require('winshift').setup() end
    }, -- Move windows around
    'tpope/vim-surround', -- Surround text with quotes, brackets, etc
    'nvim-treesitter/playground', -- Treesitter playground,
    'nvim-treesitter/nvim-treesitter-textobjects', -- Treesitter text objects
    {"b0o/incline.nvim", init = function() require("incline").setup() end}, -- Floating statusline
    "nvim-pack/nvim-spectre", -- Search and replace
    {
        "glepnir/lspsaga.nvim",
        branch = "main",
        init = function() require('lspsaga').setup({}) end
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
    }, {
        'nvim-tree/nvim-tree.lua',
        init = function() require('nvim-tree').setup() end,
        dependencies = {'nvim-tree/nvim-web-devicons'},
        tag = 'nightly'
    }, 'github/copilot.vim', -- Copilot
    {
        'TimUntersberger/neogit', -- Magit for neovim
        dependencies = 'nvim-lua/plenary.nvim'
    }, 'tpope/vim-fugitive', -- Git wrapper for vim
    'chentoast/marks.nvim', 'hrsh7th/cmp-vsnip', -- Snippets for completion
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
        dependencies = {{'nvim-lua/plenary.nvim'}}
    }, -- Telescope
    {
        'nvim-telescope/telescope-file-browser.nvim',
        init = function()
            local telescope = require("telescope")
            telescope.load_extension "file_browser"
            telescope.load_extension "workspaces"
        end
    }, -- File browse for telescope
    {
        'goolord/alpha-nvim',
        init = function()
            require'alpha'.setup(require'alpha.themes.startify'.config)
        end
    }, -- Better dashboard when opening neovim
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'}, -- Syntax and so much more
    {
        'ggandor/leap.nvim',
        init = function() require('leap').set_default_keymaps() end
    }, -- "Neovim's answer to the mouse" Jump using 's' and two chars
    'tpope/vim-commentary', -- Comment out blocks using "gc"
    {
        'akinsho/bufferline.nvim',
        version = "v3.*",
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
    {"catppuccin/nvim", name = "catppuccin"}, 'p00f/nvim-ts-rainbow', -- Rainbow matching brackets
    "lukas-reineke/indent-blankline.nvim", -- Show indentline
    'feline-nvim/feline.nvim', -- Line
    {
        'j-hui/fidget.nvim',
        tag = "legacy",
        init = function() require('fidget').setup() end
    }, -- Show LSP progress anguage specific
    {'Olical/conjure', ft = {'clojure'}}, -- Clojure 
    'simrat39/rust-tools.nvim'
})

