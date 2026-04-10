-- ── Built-in plugin manager (Neovim 0.12) ────────────────────────────────────
-- Run :lua vim.pack.update() to update all plugins.
-- The lockfile (nvim-pack-lock.json) is in this config directory — keep it
-- under version control.
--
-- vim.pack is NOT a lazy-loading framework; all plugins load at startup unless
-- you use packadd manually. This is intentional — we keep the plugin list lean.

vim.pack.add({

    -- ── Dependencies ─────────────────────────────────────────────────────────
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/nvim-tree/nvim-web-devicons',

    -- ── Colorscheme (loaded first so everything else inherits it) ─────────────
    'https://github.com/catppuccin/nvim',

    -- ── Treesitter ────────────────────────────────────────────────────────────
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',

    -- ── Fuzzy finding ─────────────────────────────────────────────────────────
    'https://github.com/ibhagwan/fzf-lua',
    -- fff.nvim: fast file/grep picker with frecency + git status.
    -- Binary is downloaded via PackChanged handler below.
    'https://github.com/dmtrKovalenko/fff.nvim',

    -- ── Git ───────────────────────────────────────────────────────────────────
    'https://github.com/lewis6991/gitsigns.nvim',
    'https://github.com/NeogitOrg/neogit',
    'https://github.com/sindrets/diffview.nvim',
    'https://github.com/tpope/vim-fugitive',

    -- ── Navigation ───────────────────────────────────────────────────────────
    'https://github.com/folke/flash.nvim',
    'https://github.com/stevearc/oil.nvim',

    -- ── LSP extras ───────────────────────────────────────────────────────────
    -- lspsaga: kept only for the floating terminal (<A-d>)
    'https://github.com/nvimdev/lspsaga.nvim',
    -- mason: binary installs only (no mason-lspconfig; we use vim.lsp.config)
    'https://github.com/williamboman/mason.nvim',

    -- ── Completion ────────────────────────────────────────────────────────────
    -- blink.cmp: fast async completion with LSP, buffer, path, snippet sources.
    -- Uses a prebuilt Rust fuzzy binary (downloaded automatically from the tag).
    { src = 'https://github.com/saghen/blink.cmp', version = 'v1.10.2' },

    -- ── Diagnostics UI ────────────────────────────────────────────────────────
    'https://github.com/folke/trouble.nvim',

    -- ── Editing utilities ─────────────────────────────────────────────────────
    'https://github.com/nvim-pack/nvim-spectre',
    'https://github.com/stevearc/conform.nvim',

    -- ── UI / Appearance ───────────────────────────────────────────────────────
    'https://github.com/akinsho/bufferline.nvim',
    'https://github.com/HiPhish/rainbow-delimiters.nvim',
    'https://github.com/brenoprata10/nvim-highlight-colors',
    'https://github.com/yorickpeterse/nvim-pqf',
    'https://github.com/karb94/neoscroll.nvim',
    'https://github.com/nvim-focus/focus.nvim',
    'https://github.com/folke/which-key.nvim',
    'https://github.com/folke/zen-mode.nvim',

    -- ── Language-specific ─────────────────────────────────────────────────────
    { src = 'https://github.com/mrcjkb/rustaceanvim',       version = 'v9.0.1' },
    { src = 'https://github.com/mrcjkb/haskell-tools.nvim', version = 'v8.1.1' },
    'https://github.com/Olical/conjure',


    -- ── Notes ─────────────────────────────────────────────────────────────────
    'https://github.com/epwalsh/obsidian.nvim',

    -- ── AI ────────────────────────────────────────────────────────────────────
    'https://github.com/github/copilot.vim',

    -- ── Personal ─────────────────────────────────────────────────────────────
    'https://github.com/TheodorRene/skriveleif',
})

-- ── Built-in opt plugins (shipped with Neovim 0.12) ──────────────────────────
vim.cmd('packadd nvim.undotree')   -- :Undotree — replaces the undotree plugin

-- ── Conjure: restrict to Clojure only ────────────────────────────────────────
-- Conjure's default filetype list includes JS, TS, Python, Lua, Rust, SQL, etc.
-- and auto-spawns REPLs on BufEnter. Restrict it to Clojure before it loads.
-- Setting a filetype to false disables that client entirely.
vim.g["conjure#filetypes"]           = { "clojure" }
vim.g["conjure#filetype#javascript"] = false
vim.g["conjure#filetype#typescript"] = false
vim.g["conjure#filetype#python"]     = false
vim.g["conjure#filetype#lua"]        = false
vim.g["conjure#filetype#rust"]       = false
vim.g["conjure#filetype#sql"]        = false

-- ── Post-install / post-update hooks ─────────────────────────────────────────
-- spec.name is the full URL when no explicit name is given, e.g.
-- "https://github.com/nvim-treesitter/nvim-treesitter"
vim.api.nvim_create_autocmd('PackChanged', {
    desc = 'Run TSUpdate after nvim-treesitter changes',
    callback = function(ev)
        if ev.data.spec.name:find('nvim-treesitter', 1, true) then
            vim.cmd('TSUpdate')
        end
    end,
})

vim.api.nvim_create_autocmd('PackChanged', {
    desc = 'Download fff.nvim binary after install/update',
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        if name:find('fff.nvim', 1, true) and (kind == 'install' or kind == 'update') then
            if not ev.data.active then
                vim.cmd.packadd('fff.nvim')
            end
            local ok, dl = pcall(require, 'fff.download')
            if ok then dl.download_or_build_binary() end
        end
    end,
})

-- ── fff.nvim configuration ────────────────────────────────────────────────────
vim.g.fff = {
    lazy_sync = true,
    layout = {
        prompt_position = 'top',
    },
}

-- ── First-boot parser bootstrap ───────────────────────────────────────────────
-- nvim-treesitter installs parsers to stdpath('data')/site/parser/ by default.
-- On first boot that directory is empty. Detect this by checking directly for
-- the typescript parser (a non-Homebrew-bundled one) and run TSUpdate if absent.
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    desc = 'Auto-run TSUpdate when compiled parsers are missing',
    callback = function()
        local ok, _ = pcall(require, 'nvim-treesitter')
        if not ok then return end
        -- The default install_dir is stdpath('data')/site; parsers live there.
        local site_parser = vim.fn.stdpath('data') .. '/site/parser/typescript.so'
        if vim.uv.fs_stat(site_parser) == nil then
            vim.notify('[nvim-treesitter] Parsers missing — running TSUpdate…', vim.log.levels.INFO)
            vim.cmd('TSUpdate')
        end
    end,
})

-- ── Plugin configuration ──────────────────────────────────────────────────────
-- Keeping configs co-located with plugin declarations for discoverability.
-- LSP-adjacent configs live in lsp.lua / diagnostics.lua instead.
--
-- All require() calls are wrapped in pcall so that the first-boot download
-- (when plugins are not yet on disk) doesn't hard-error. On the next startup
-- everything will be present and the setups will run normally.
local function setup(mod, opts)
    local ok, plugin = pcall(require, mod)
    if not ok then return end
    if type(plugin.setup) == 'function' then
        plugin.setup(opts or {})
    end
end

-- Colorscheme
local ok_ctp, catppuccin = pcall(require, 'catppuccin')
if ok_ctp then
    catppuccin.setup({
        integrations = {
            gitsigns           = true,
            lsp_trouble        = true,
            neogit             = true,
            treesitter         = true,
            which_key          = true,
            rainbow_delimiters = true,
            native_lsp = {
                enabled = true,
                virtual_text = {
                    errors      = { 'italic' },
                    hints       = { 'italic' },
                    warnings    = { 'italic' },
                    information = { 'italic' },
                },
                underlines = {
                    errors      = { 'underline' },
                    hints       = { 'underline' },
                    warnings    = { 'underline' },
                    information = { 'underline' },
                },
            },
        },
    })
    vim.cmd('colorscheme catppuccin-macchiato')
end

-- Treesitter
-- The new nvim-treesitter (v1) ships queries under runtime/queries/ rather than
-- queries/ at the plugin root. Neovim's packadd does not automatically add
-- <plugin>/runtime to rtp, so we do it explicitly.
--
-- IMPORTANT: use append (not prepend) so that $VIMRUNTIME/queries/ keeps
-- priority for the 7 languages that ship with bundled parsers + queries in
-- Neovim 0.12 (lua, c, vim, vimdoc, markdown, markdown_inline, query).
-- Those bundled queries are in sync with the bundled parsers; the newer
-- nvim-treesitter queries reference grammar fields that the bundled parsers
-- don't have yet, causing "Invalid field name" errors.
-- For all other languages nvim-treesitter's queries fill in the gaps.
local ts_pack_path = vim.fn.stdpath('data') .. '/site/pack/core/opt/nvim-treesitter'
local ts_runtime   = ts_pack_path .. '/runtime'
if vim.uv.fs_stat(ts_runtime) then
    vim.opt.rtp:append(ts_runtime)
end

local ok_ts, ts_configs = pcall(require, 'nvim-treesitter.configs')
if ok_ts then
    ts_configs.setup({
        ensure_installed = {
            'bash', 'c', 'cpp', 'css', 'dockerfile', 'go', 'html',
            'java', 'javascript', 'json', 'lua', 'python', 'regex',
            'rust', 'toml', 'typescript', 'yaml', 'haskell', 'query',
            'tsx', 'vue', 'svelte', 'markdown', 'markdown_inline',
        },
        highlight = {
            enable = true,
            -- Disable on very large files to avoid slowdowns
            disable = function(_, buf)
                local ok2, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
                return ok2 and stats and stats.size > 50 * 1024
            end,
            additional_vim_regex_highlighting = false,
        },
        -- NOTE: incremental selection (an/in/]n/[n) is built-in in 0.12 via
        -- textDocument/selectionRange (LSP) or Treesitter nodes — no plugin config needed.
        textobjects = {
            select = {
                enable    = true,
                lookahead = true,
                keymaps = {
                    ['af'] = '@function.outer',
                    ['if'] = '@function.inner',
                },
                selection_modes = {
                    ['@parameter.outer'] = 'v',
                    ['@function.outer']  = 'V',
                },
                include_surrounding_whitespace = true,
            },
        },
    })
end

-- fzf-lua
setup('fzf-lua')

-- Gitsigns
local ok_gs, gitsigns = pcall(require, 'gitsigns')
if ok_gs then
    gitsigns.setup({
        on_attach = function(bufnr)
            GITSIGNS_MAPPINGS(bufnr)
        end,
    })
end

-- Neogit (deferred — only needed when you open it)
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    desc = 'Deferred neogit setup',
    callback = function()
        setup('neogit', {
            disable_commit_confirmation = true,
            disable_hint                = true,
            integrations                = { diffview = true },
            sections                    = { stashes = { folded = true } },
        })
    end,
})

-- Oil (file manager)
setup('oil')

-- lspsaga — floating terminal only; suppress lightbulb sign (deferred)
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    desc = 'Deferred lspsaga setup',
    callback = function()
        setup('lspsaga', { lightbulb = { sign = false } })
    end,
})

-- Mason: must run eagerly — setup() prepends mason/bin to $PATH, which LSP
-- servers installed via Mason depend on. Deferring it means lua-language-server
-- and others aren't found when vim.lsp.enable() fires.
setup('mason')

-- Trouble
setup('trouble')

-- Bufferline
setup('bufferline')

-- Rainbow delimiters
local ok_rd, rd = pcall(require, 'rainbow-delimiters')
if ok_rd then
    vim.g.rainbow_delimiters = {
        strategy  = { [''] = rd.strategy['global'], vim = rd.strategy['local'] },
        query     = { [''] = 'rainbow-delimiters', lua = 'rainbow-blocks' },
        highlight = {
            'RainbowDelimiterRed',    'RainbowDelimiterYellow',
            'RainbowDelimiterBlue',   'RainbowDelimiterOrange',
            'RainbowDelimiterGreen',  'RainbowDelimiterViolet',
            'RainbowDelimiterCyan',
        },
    }
end

-- Inline color highlights (CSS, Tailwind, etc.)
setup('nvim-highlight-colors')

-- Better quickfix formatting
setup('pqf')

-- Smooth scrolling
setup('neoscroll', {
    mappings         = { '<C-u>', '<C-d>', 'zt', 'zz', 'zb', '<C-e>', '<C-y>' },
    performance_mode = false,  -- performance_mode falls back to removed TSBufEnable on treesitter failure
    hide_cursor      = false,
    respect_scrolloff    = true,
    cursor_scrolls_alone = true,
})

-- Auto-resize focused window
setup('focus')

-- Which-key
setup('which-key')

-- conform.nvim: formatter manager (replaces neoformat)
local ok_conform, conform = pcall(require, 'conform')
if ok_conform then
    conform.setup({
        formatters_by_ft = {
            -- JS/TS: prefer project-local prettier, fall back to prettierd
            javascript      = { 'prettier' },
            javascriptreact = { 'prettier' },
            typescript      = { 'prettier' },
            typescriptreact = { 'prettier' },
            graphql         = { 'prettier' },
            html            = { 'prettier' },
            css             = { 'prettier' },
            json            = { 'prettier' },
            jsonc           = { 'prettier' },
            yaml            = { 'prettier' },
            markdown        = { 'prettier' },
            -- Systems
            rust            = { 'rustfmt' },
            go              = { 'gofmt' },
            c               = { 'clang_format' },
            cpp             = { 'clang_format' },
            -- Data / query
            sql             = { 'sqlfmt' },
            python          = { 'black' },
            lua             = { 'stylua' },
        },
        -- Use project-local node_modules/.bin executables when available
        formatters = {
            prettier = {
                -- conform looks for prettier in node_modules/.bin automatically
                -- via its built-in node_modules detection
            },
            rustfmt = {
                args = { '--edition', '2024', '--emit=stdout' },
            },
        },
        -- Don't auto-format on save (explicit <space>f only)
        format_on_save = false,
    })
end

-- Obsidian (deferred — only needed for markdown files)
vim.api.nvim_create_autocmd('BufReadPre', {
    pattern  = '*.md',
    once     = true,
    desc     = 'Deferred obsidian setup',
    callback = function()
        setup('obsidian', {
            workspaces = { { name = 'personal', path = '~/Documents/inner-sanctum-main' } },
        })
    end,
})

-- Copilot: disable tab map (we use <C-J> in keymaps.lua)
vim.g.copilot_no_tab_map = true

-- Flash
setup('flash')

-- blink.cmp
local ok_blink, blink = pcall(require, 'blink.cmp')
if ok_blink then
    blink.setup({
        keymap = {
            preset = 'none',   -- define all mappings explicitly below
            ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
            ['<C-e>']     = { 'hide' },
            ['<C-y>']     = { 'select_and_accept' },
            ['<C-k>']     = { 'show_signature', 'hide_signature', 'fallback' },
            ['<Tab>']     = { 'select_next', 'fallback' },
            ['<S-Tab>']   = { 'select_prev', 'fallback' },
            ['<C-n>']     = { 'select_next', 'fallback' },
            ['<C-p>']     = { 'select_prev', 'fallback' },
            ['<C-d>']     = { 'scroll_documentation_down' },
            ['<C-u>']     = { 'scroll_documentation_up' },
        },
        appearance = {
            nerd_font_variant = 'mono',
        },
        completion = {
            documentation = {
                auto_show       = true,
                auto_show_delay_ms = 200,
                window = { border = 'rounded' },
            },
            menu = {
                border = 'rounded',
                draw = {
                    -- Show icon + kind label + label + source name
                    columns = {
                        { 'kind_icon' },
                        { 'label', 'label_description', gap = 1 },
                        { 'kind' },
                    },
                },
            },
            -- Accept on <C-y>; don't auto-insert on selection change
            list = { selection = { preselect = false, auto_insert = false } },
        },
        sources = {
            default = { 'lsp', 'path', 'buffer' },
        },
        fuzzy = { implementation = 'prefer_rust_with_warning' },
        signature = { enabled = true, window = { border = 'rounded' } },
    })
end

-- Rustaceanvim on_attach is wired in lsp.lua via vim.g.rustaceanvim
