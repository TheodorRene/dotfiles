require('gitsigns').setup {
    on_attach = function(bufnr) TRC_GITSIGNS_MAPPINGS(bufnr) end
}
local ctp_feline = require('catppuccin.groups.integrations.feline')
-- require("notify").setup({
--   background_colour = "#000000",
-- })
require('feline').setup({components = ctp_feline.get()})
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
require('neogit').setup {
    -- kind="floating",
    disable_commit_confirmation = true,
    disable_hint = true,
    integrations = {diffview = true},
    sections = {stashes = {folded = true}}
}

local fb_actions = require"telescope".extensions.file_browser.actions
require("telescope").setup {
    pickers = {
        defaults = {file_ignore_patterns = {"node_modules", ".git"}},
        git_files = {theme = "dropdown", previewer = false},
        buffers = {theme = "dropdown", previewer = false},
        find_files = {theme = "dropdown", previewer = false}
    },

    extensions = {
        -- workspaces = {
        --     keep_insert = "true",
        -- },
        file_browser = {
            theme = "ivy",
            -- disables netrw and use telescope-file-browser in its place
            hijack_netrw = true,
            mappings = {
                ["i"] = {
                    ["<C-e>"] = fb_actions.create,
                    ["<C-r>"] = fb_actions.rename
                }
            }
        }
    }
}

require("telescope").load_extension "file_browser"
-- Treesitter
require'nvim-treesitter.configs'.setup {
    ensure_installed = {"bash", "c", "cpp", "css", "dockerfile", "go", "html",
                        "java", "javascript", "json", "lua", "python", "regex",
                        "rust", "toml", "typescript", "yaml"},
    highlight = {
        enable = true,
        -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
        disable = function(_, buf)
            local max_filesize = 50 * 1024 -- 100 KB
            local ok, stats = pcall(vim.loop.fs_stat,
                                    vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
                return true
            end
        end,
        additional_vim_regex_highlighting = false
    },

    rainbow = {enable = true, extended_mode = true, max_file_lines = nil},
    textobjects = {
        select = {
            enable = true,

            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,

            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner"
                --       ["ac"] = "@class.outer",
                -- You can optionally set descriptions to the mappings (used in the desc parameter of
                -- nvim_buf_set_keymap) which plugins like which-key display
                --        ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
            },
            -- You can choose the select mode (default is charwise 'v')
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * method: eg 'v' or 'o'
            -- and should return the mode ('v', 'V', or '<c-v>') or a table
            -- mapping query_strings to modes.
            selection_modes = {
                ['@parameter.outer'] = 'v', -- charwise
                ['@function.outer'] = 'V' -- linewise
            },
            -- If you set this to `true` (default is `false`) then any textobject is
            -- extended to include preceding or succeeding whitespace. Succeeding
            -- whitespace has priority in order to act similarly to eg the built-in
            -- `ap`.
            --
            -- Can also be a function which gets passed a table with the keys
            -- * query_string: eg '@function.inner'
            -- * selection_mode: eg 'v'
            -- and should return true of false
            include_surrounding_whitespace = true
        },
    }
}

-- Colorscheme
vim.cmd [[colorscheme catppuccin-macchiato]]

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

