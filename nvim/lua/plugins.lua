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
    {
        'neovim/nvim-lspconfig',
        event = {"BufReadPre", "BufNewFile"},
        dependencies = {
            "williamboman/mason.nvim", "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer", "onsails/lspkind-nvim",
            "hrsh7th/vim-vsnip", "hrsh7th/cmp-vsnip",
            "hrsh7th/vim-vsnip-integ"
        },
        config = function()
            if vim.env.NVIM_SKIP_LSP_CONF then
                return
            end
            require('lsp_conf')
        end
    }, {
        'hrsh7th/nvim-cmp',
        event = "InsertEnter",
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-vsnip',
            'hrsh7th/vim-vsnip',
            'hrsh7th/vim-vsnip-integ',
            'onsails/lspkind-nvim'
        },
        config = function()
            if vim.env.NVIM_SKIP_LSP_CONF then
                return
            end
            local cmp = require 'cmp'
            local lspkind = require 'lspkind'

            vim.o.completeopt = 'menuone,noselect'
            cmp.setup {
                snippet = {
                    expand = function(args)
                        vim.fn["vsnip#anonymous"](args.body)
                    end
                },
                mapping = {
                    ['<C-p>'] = cmp.mapping.select_prev_item(),
                    ['<C-n>'] = cmp.mapping.select_next_item(),
                    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.close(),
                    ['<CR>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true
                    },
                    ['<Tab>'] = function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        else
                            fallback()
                        end
                    end,
                    ['<S-Tab>'] = function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        else
                            fallback()
                        end
                    end
                },
                sources = {
                    {name = 'nvim_lsp'}, {name = 'buffer'},
                    {name = 'vim-dadbod-completion'}
                },
                formatting = {
                    format = lspkind.cmp_format({
                        mode = 'symbol-text',
                        maxwidth = 50
                    })
                }
            }
        end
    }, {
        'hrsh7th/cmp-nvim-lsp',
        lazy = true
    }, {
        'hrsh7th/cmp-buffer',
        lazy = true
    }, {
        'hrsh7th/cmp-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip-integ',
        lazy = true
    }, {
        'onsails/lspkind-nvim',
        lazy = true
    }, {

        'hrsh7th/cmp-nvim-lsp',
        lazy = true
    }, {
        'hrsh7th/cmp-buffer',
        lazy = true
    }, {
        'hrsh7th/cmp-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip-integ',
        lazy = true
    }, {
        'onsails/lspkind-nvim',
        lazy = true
    }, {

        'mrcjkb/haskell-tools.nvim',
        version = '^4',
        ft = {"haskell", "lhaskell", "cabal"}
    }, "nvim-lua/plenary.nvim", {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        lazy = true
    }, {
        "marilari88/twoslash-queries.nvim",
        ft = {"typescript", "typescriptreact", "javascript", "javascriptreact"},
        dependencies = {"nvim-lspconfig"}
    }, {
        'lewis6991/gitsigns.nvim',
        event = "BufReadPre",
        config = function()
            require('gitsigns').setup {
                on_attach = function(bufnr) TRC_GITSIGNS_MAPPINGS(bufnr) end
            }
        end
    }, {
        'mbbill/undotree',
        cmd = 'UndotreeToggle'
    }, {
        'sbdchd/neoformat',
        cmd = {'Neoformat', 'NeoformatAuto', 'NeoformatDisable', 'NeoformatEnable'},
        init = function()
            vim.g.neoformat_try_node_exe = 1
            vim.g.neoformat_rust_rustfmt = {
                exe = '/Users/thca/.cargo/bin/rustfmt',
                args = {'--edition', '2024'},
                stdin = 1,
            }
            vim.g.neoformat_enabled_rust = {'rustfmt'}
        end
    }, {
        'yorickpeterse/nvim-pqf',
        event = "VeryLazy",
        config = function() require('pqf').setup() end
    }, {
        'mattkubej/jest.nvim',
        ft = {"javascript", "typescript", "javascriptreact", "typescriptreact"},
        dependencies = {"nvim-lua/plenary.nvim"}
    }, {
        'HiPhish/rainbow-delimiters.nvim',
        event = "BufReadPost",
        config = function()
            local rainbow_delimiters = require 'rainbow-delimiters'
            vim.g.rainbow_delimiters = {
                strategy = {
                    [''] = rainbow_delimiters.strategy['global'],
                    vim = rainbow_delimiters.strategy['local']
                },
                query = {[''] = 'rainbow-delimiters', lua = 'rainbow-blocks'},
                highlight = {
                    'RainbowDelimiterRed', 'RainbowDelimiterYellow',
                    'RainbowDelimiterBlue', 'RainbowDelimiterOrange',
                    'RainbowDelimiterGreen', 'RainbowDelimiterViolet',
                    'RainbowDelimiterCyan'
                }
            }
        end
    }, {
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
    }, {
        'stevearc/oil.nvim',
        cmd = 'Oil',
        config = function() require('oil').setup() end
    }, {
        "epwalsh/obsidian.nvim",
        version = "*",
        ft = "markdown",
        dependencies = {"nvim-lua/plenary.nvim"},
        opts = {
            workspaces = {{name = "personal", path = "~/Documents/inner-sanctum-main"}}
        }
    }, {
        "monkoose/matchparen.nvim",
        event = "BufReadPost",
        config = function() require('matchparen').setup() end
    }, {
        'brenoprata10/nvim-highlight-colors',
        event = "BufReadPost",
        config = function() require('nvim-highlight-colors').setup() end
    }, {
        "b0o/incline.nvim",
        config = function() require("incline").setup() end,
        enabled = false
    }, {
        "nvim-pack/nvim-spectre",
        cmd = "Spectre"
    }, {
        "glepnir/lspsaga.nvim",
        branch = "main",
        event = "LspAttach",
        config = function()
            require('lspsaga').setup({lightbulb = {sign = false}})
        end
    }, {
        'karb94/neoscroll.nvim',
        event = "WinScrolled",
        config = function()
            require('neoscroll').setup({
                mappings = {
                    '<C-u>', '<C-d>', 'zt', 'zz', 'zb', '<C-e>', '<C-y>'
                },
                performance_mode = true
            })
        end
    }, {
        'github/copilot.vim',
        event = "InsertEnter"
    }, {
        'TimUntersberger/neogit',
        cmd = "Neogit",
        dependencies = {'nvim-lua/plenary.nvim'},
        config = function()
            require('neogit').setup {
                disable_commit_confirmation = true,
                disable_hint = true,
                integrations = {diffview = true},
                sections = {stashes = {folded = true}}
            }
        end
    }, {
        'tpope/vim-fugitive',
        cmd = {"Git", "G"}
    }, {
        "CopilotC-Nvim/CopilotChat.nvim",
        cmd = {"CopilotChat", "CopilotChatToggle", "CopilotChatExplain"},
        dependencies = {{"nvim-lua/plenary.nvim", branch = "master"}},
        build = "make tiktoken",
        opts = {}
    }, {
        'sindrets/diffview.nvim',
        cmd = {"DiffviewOpen", "DiffviewFileHistory"}
    }, {
        "ibhagwan/fzf-lua",
        cmd = "FzfLua",
        dependencies = {"nvim-tree/nvim-web-devicons"},
        opts = {}
    }, {
        'nvim-focus/focus.nvim',
        version = false,
        event = "VimEnter",
        config = function() require('focus').setup() end
    }, {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function() require("which-key").setup {} end
    }, {
        "olimorris/codecompanion.nvim",
        cmd = {"CodeCompanion", "CodeCompanionChat", "CodeCompanionActions"},
        opts = {},
        dependencies = {
            "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter"
        }
    }, {
        'nvim-telescope/telescope.nvim',
        cmd = "Telescope",
        version = '0.1.x',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'nvim-telescope/telescope-fzf-native.nvim'
        },
        config = function()
            require("telescope").setup {
                pickers = {
                    defaults = {
                        file_ignore_patterns = {
                            "node_modules", ".git", ".*%.test%.tsx",
                            ".*%.test%.ts"
                        },
                        preview = {treesitter = true}
                    },
                    git_files = {theme = "dropdown", previewer = false},
                    buffers = {theme = "dropdown", previewer = false},
                    find_files = {theme = "dropdown", previewer = false}
                }
            }
            require("telescope").load_extension "fzf"
        end
    }, {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        event = {"BufReadPost", "BufNewFile"},
        config = function()
            require'nvim-treesitter.configs'.setup {
                ensure_installed = {
                    "bash", "c", "cpp", "css", "dockerfile", "go", "html",
                    "java", "javascript", "json", "lua", "python", "regex",
                    "rust", "toml", "typescript", "yaml", "haskell", "query",
                    "tsx", "vue", "svelte"
                },
                highlight = {
                    enable = true,
                    disable = function(_, buf)
                        local max_filesize = 50 * 1024
                        local ok, stats = pcall(vim.loop.fs_stat,
                                                vim.api.nvim_buf_get_name(buf))
                        if ok and stats and stats.size > max_filesize then
                            return true
                        end
                    end,
                    additional_vim_regex_highlighting = false
                },
                rainbow = {
                    enable = true,
                    extended_mode = true,
                    max_file_lines = nil
                },
                textobjects = {
                    select = {
                        enable = true,
                        lookahead = true,
                        keymaps = {
                            ["af"] = "@function.outer",
                            ["if"] = "@function.inner"
                        },
                        selection_modes = {
                            ['@parameter.outer'] = 'v',
                            ['@function.outer'] = 'V'
                        },
                        include_surrounding_whitespace = true
                    }
                }
            }
        end
    }, {
        'akinsho/bufferline.nvim',
        version = "*",
        event = "VimEnter",
        dependencies = 'nvim-tree/nvim-web-devicons'
    }, {
        'neovim/nvim-lspconfig',
        event = {"BufReadPre", "BufNewFile"},
        dependencies = {
            "williamboman/mason.nvim", "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer", "onsails/lspkind-nvim",
            "hrsh7th/vim-vsnip", "hrsh7th/cmp-vsnip",
            "hrsh7th/vim-vsnip-integ"
        },
        config = function()
            if vim.env.NVIM_SKIP_LSP_CONF then
                return
            end
            require('lsp_conf')
        end
    }, {
        'hrsh7th/nvim-cmp',
        event = "InsertEnter",
        dependencies = {
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-buffer',
            'hrsh7th/cmp-vsnip',
            'hrsh7th/vim-vsnip',
            'hrsh7th/vim-vsnip-integ',
            'onsails/lspkind-nvim'
        },
        config = function()
            if vim.env.NVIM_SKIP_LSP_CONF then
                return
            end
            local cmp = require 'cmp'
            local lspkind = require 'lspkind'

            vim.o.completeopt = 'menuone,noselect'
            cmp.setup {
                snippet = {
                    expand = function(args)
                        vim.fn["vsnip#anonymous"](args.body)
                    end
                },
                mapping = {
                    ['<C-p>'] = cmp.mapping.select_prev_item(),
                    ['<C-n>'] = cmp.mapping.select_next_item(),
                    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.close(),
                    ['<CR>'] = cmp.mapping.confirm {
                        behavior = cmp.ConfirmBehavior.Replace,
                        select = true
                    },
                    ['<Tab>'] = function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        else
                            fallback()
                        end
                    end,
                    ['<S-Tab>'] = function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        else
                            fallback()
                        end
                    end
                },
                sources = {
                    {name = 'nvim_lsp'}, {name = 'buffer'},
                    {name = 'vim-dadbod-completion'}
                },
                formatting = {
                    format = lspkind.cmp_format({
                        mode = 'symbol-text',
                        maxwidth = 50
                    })
                }
            }
        end
    }, {
        'hrsh7th/cmp-nvim-lsp',
        lazy = true
    }, {
        'hrsh7th/cmp-buffer',
        lazy = true
    }, {
        'hrsh7th/cmp-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip',
        lazy = true
    }, {
        'hrsh7th/vim-vsnip-integ',
        lazy = true
    }, {
        'onsails/lspkind-nvim',
        lazy = true
    }, {
        "folke/trouble.nvim",
        opts = {},
        cmd = "Trouble",
        dependencies = "nvim-tree/nvim-web-devicons"
    }, {
        'TheodorRene/skriveleif',
        event = "VeryLazy"
    }, {
        'nvim-tree/nvim-web-devicons',
        lazy = true
    }, {
        'folke/tokyonight.nvim',
        lazy = true
    }, {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = true,
        enabled = false,
        dependencies = {"nvim-tree/nvim-web-devicons"},
        config = function() require("nvim-tree").setup {} end
    }, {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                integrations = {
                    cmp = true,
                    gitgutter = false,
                    gitsigns = true,
                    leap = true,
                    lsp_saga = true,
                    lsp_trouble = true,
                    neogit = true,
                    nvimtree = true,
                    symbols_outline = true,
                    telescope = true,
                    treesitter = true,
                    ts_rainbow = true,
                    which_key = true,
                    native_lsp = {
                        enabled = true,
                        virtual_text = {
                            errors = {"italic"},
                            hints = {"italic"},
                            warnings = {"italic"},
                            information = {"italic"}
                        },
                        underlines = {
                            errors = {"underline"},
                            hints = {"underline"},
                            warnings = {"underline"},
                            information = {"underline"}
                        }
                    }
                }
            })
            vim.cmd [[colorscheme catppuccin-macchiato]]
        end
    }, {
        'nvim-lualine/lualine.nvim',
        dependencies = {'nvim-tree/nvim-web-devicons'},
        event = "VimEnter",
        config = function() require('lualine').setup() end
    }, {
        'j-hui/fidget.nvim',
        event = "LspAttach",
        config = function() require('fidget').setup() end
    }, {
        'Olical/conjure',
        ft = {'clojure'},
        branch = "main"
    }, {
        'mrcjkb/rustaceanvim',
        version = '^6',
        ft = {'rust'}
    }, {
        'gelguy/wilder.nvim',
        event = "CmdlineEnter",
        config = function()
            require('wilder').setup {modes = {':', '/', '?'}}
        end
    }, {
        "folke/zen-mode.nvim",
        cmd = "ZenMode"
    }
})
