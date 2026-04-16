-- ── LSP configuration (Neovim 0.12 native) ───────────────────────────────────
-- Uses vim.lsp.config / vim.lsp.enable — no nvim-lspconfig required.
-- Mason is used only for installing server binaries (:Mason).
-- Set NVIM_SKIP_LSP_CONF=1 to skip all LSP setup (fast/lightweight sessions).

if vim.env.NVIM_SKIP_LSP_CONF then
    return
end

-- ── Shared on_attach ──────────────────────────────────────────────────────────
-- Called for every server. Buffer-local LSP keymaps live here.
-- Most mappings are now 0.12 built-in defaults (grn, gra, gri, grr, grt, grx, gO).
-- We only define the ones that differ from or extend those defaults.
local function on_attach(client, bufnr)
    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, buffer = bufnr, desc = desc })
    end

    -- Go to definition via fzf-lua (opens in current window, supports multi-result)
    map('n', 'gd', function()
        require('fzf-lua').lsp_definitions()
    end, 'LSP: definitions')

    -- Implementations via fzf-lua
    map('n', 'gi', function()
        require('fzf-lua').lsp_implementations()
    end, 'LSP: implementations')

    -- References via fzf-lua in a vsplit (matches old behaviour)
    map('n', 'grr', function()
        require('fzf-lua').lsp_references({ jump_type = 'vsplit' })
    end, 'LSP: references (vsplit)')

    -- Hover with rounded border (built-in, explicit border)
    map('n', 'K', function()
        vim.lsp.buf.hover({ border = 'rounded' })
    end, 'LSP: hover')

    -- Signature help
    map('n', '<C-k>', vim.lsp.buf.signature_help, 'LSP: signature help')

    -- Diagnostics float
    map('n', '<C-x>e', vim.diagnostic.open_float, 'LSP: open diagnostic float')
    map('n', '<A-e>',  vim.diagnostic.open_float, 'LSP: open diagnostic float')

    -- Diagnostic navigation
    map('n', '[d',    vim.diagnostic.goto_prev, 'LSP: previous diagnostic')
    map('n', ']d',    vim.diagnostic.goto_next, 'LSP: next diagnostic')
    map('n', '<C-a>d', vim.diagnostic.goto_next, 'LSP: next diagnostic')
    map('n', '<C-a>D', vim.diagnostic.goto_prev, 'LSP: previous diagnostic')

    -- Workspace diagnostics via fzf-lua
    map('n', '<C-x>d', function()
        require('fzf-lua').diagnostics_workspace()
    end, 'LSP: workspace diagnostics')

    -- Autofix: jump to next diagnostic then trigger code action
    -- (grn=rename, gra=code_action are 0.12 defaults — no need to redefine)
    map('n', '<C-x>q', function()
        vim.diagnostic.goto_next()
        vim.lsp.buf.code_action()
    end, 'LSP: autofix (next diag + code action)')

    -- Restart LSP
    map('n', '<C-x>r', '<cmd>LspRestart<CR>', 'LSP: restart')

    -- Type definition (grt is the 0.12 default, also map <space>D for muscle memory)
    map('n', '<space>D', vim.lsp.buf.type_definition, 'LSP: type definition')

    -- Codelens
    map('n', '<C-x>h', vim.lsp.codelens.run, 'LSP: run codelens')

    -- Format visual selection as graphql (conform, explicit formatter)
    map('v', '<space>fq', function()
        require('conform').format({ async = true, formatters = { 'prettier' } })
    end, 'Format: graphql selection')

    -- ── Inlay hints ───────────────────────────────────────────────────────────
    -- Enable globally; toggle with <leader>i
    if client:supports_method('textDocument/inlayHint') then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        map('n', '<leader>i', function()
            vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
                { bufnr = bufnr }
            )
        end, 'LSP: toggle inlay hints')
    end

    -- Rename: <C-a>r for muscle memory (grn is the 0.12 default)
    map('n', '<C-a>r', vim.lsp.buf.rename, 'LSP: rename')

    -- Code action: <C-.> / <A-.> / <C-a>a for muscle memory (gra is 0.12 default)
    map('n', '<C-.>',  vim.lsp.buf.code_action, 'LSP: code action')
    map('n', '<A-.>',  vim.lsp.buf.code_action, 'LSP: code action')
    map('n', '<C-a>a', vim.lsp.buf.code_action, 'LSP: code action')

    -- Declaration (rarely used but keep it)
    map('n', 'gD', vim.lsp.buf.declaration, 'LSP: declaration')
end

-- Expose on_attach for rustaceanvim (configured below)
_G.LSP_ON_ATTACH = on_attach

-- ── Server configurations ────────────────────────────────────────────────────
-- Pattern: vim.lsp.config['name'] = { ... }, then vim.lsp.enable('name')
-- root_markers: list of files/dirs that indicate the project root.
-- Nested lists = equal-priority markers (0.12 feature).

vim.lsp.config['ts_ls'] = {
    cmd       = { 'typescript-language-server', '--stdio' },
    filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
}

vim.lsp.config['eslint'] = {
    cmd = {
        '/Users/thca/.local/share/nvim/mason/bin/vscode-eslint-language-server',
        '--stdio',
    },
    filetypes    = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
    root_markers = {
        '.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json',
        'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
        'package.json', '.git',
    },
    workspace_required = false,
    settings = {
        validate              = 'on',
        run                   = 'onType',
        useESLintClass        = false,
        -- nodePath must be explicitly null (not nil/undefined) so the eslint
        -- server's `if (settings.nodePath !== null)` guard works correctly.
        -- If it's undefined the guard is bypassed and path.isAbsolute(undefined)
        -- throws "-32603 path must be of type string".
        nodePath              = vim.NIL,
        experimental          = { useFlatConfig = false },
        codeAction            = {
            disableRuleComment = { enable = true, location = 'separateLine' },
            showDocumentation  = { enable = true },
        },
        workingDirectory      = { mode = 'location' },
        problems              = { shortenToSingleLine = false },
        format                = true,
    },
}

-- ── eslint: inject workspaceFolder into workspace/configuration responses ─────
-- Neovim 0.12 does not call on_new_config (nvim-lspconfig concept).
-- Instead we wrap the workspace/configuration handler: when the eslint server
-- requests its settings (section=''), we ensure settings.workspaceFolder is
-- populated with the client's actual root_dir so the server never receives
-- undefined as a path argument.
local _orig_ws_cfg = vim.lsp.handlers['workspace/configuration']
vim.lsp.handlers['workspace/configuration'] = function(err, params, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if client and client.name == 'eslint' then
        local folder = client.root_dir or vim.fn.expand('%:p:h')
        client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
            workspaceFolder = {
                uri  = vim.uri_from_fname(folder),
                name = vim.fn.fnamemodify(folder, ':t'),
            },
        })
    end
    return _orig_ws_cfg(err, params, ctx)
end

vim.lsp.config['pyright'] = {
    cmd       = { 'pyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', '.git' },
    settings  = { python = { analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true } } },
}

vim.lsp.config['lua_ls'] = {
    cmd       = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
    settings  = {
        Lua = {
            runtime     = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace   = {
                -- Only add the Neovim runtime for API completions — NOT the
                -- entire rtp. nvim_get_runtime_file('', true) returns hundreds
                -- of paths that lua_ls must index on every start (no caching).
                library = { vim.env.VIMRUNTIME },
                checkThirdParty = false,
            },
            telemetry   = { enable = false },
        },
    },
}

vim.lsp.config['gopls'] = {
    cmd       = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.work', 'go.mod', '.git' },
}

vim.lsp.config['hls'] = {
    cmd       = { 'haskell-language-server-wrapper', '--lsp' },
    filetypes = { 'haskell', 'lhaskell', 'cabal' },
    root_markers = { 'hie.yaml', 'stack.yaml', 'cabal.project', '*.cabal', '.git' },
}

vim.lsp.config['clojure_lsp'] = {
    cmd       = { 'clojure-lsp' },
    filetypes = { 'clojure', 'edn' },
    root_markers = { 'project.clj', 'deps.edn', 'build.boot', 'shadow-cljs.edn', '.git' },
}

vim.lsp.config['elmls'] = {
    cmd       = { 'elm-language-server' },
    filetypes = { 'elm' },
    root_markers = { 'elm.json', '.git' },
}

vim.lsp.config['jdtls'] = {
    cmd       = { 'jdtls' },
    filetypes = { 'java' },
    root_markers = { 'pom.xml', 'build.gradle', '.git' },
}

vim.lsp.config['lemminx'] = {
    cmd       = { 'lemminx' },
    filetypes = { 'xml', 'xsd', 'xsl', 'xslt', 'svg' },
    root_markers = { '.git' },
}

vim.lsp.config['jsonls'] = {
    cmd       = { 'vscode-json-language-server', '--stdio' },
    filetypes = { 'json', 'jsonc' },
    root_markers = { '.git' },
}

vim.lsp.config['html'] = {
    cmd       = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html' },
    root_markers = { 'package.json', '.git' },
}

vim.lsp.config['clangd'] = {
    cmd       = { 'clangd' },
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
    root_markers = { 'compile_commands.json', 'compile_flags.txt', '.clangd', 'CMakeLists.txt', '.git' },
}

-- ── Enable all servers ────────────────────────────────────────────────────────
local servers = {
    'ts_ls', 'eslint', 'pyright', 'lua_ls', 'gopls',
    'hls', 'clojure_lsp', 'elmls', 'jdtls',
    'lemminx', 'jsonls', 'html', 'clangd',
}

for _, name in ipairs(servers) do
    -- Wire on_attach into each config before enabling
    local cfg = vim.lsp.config[name] or {}
    local existing_on_attach = cfg.on_attach
    cfg.on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        if existing_on_attach then existing_on_attach(client, bufnr) end
    end
    vim.lsp.config[name] = cfg
    vim.lsp.enable(name)
end

-- ── Rust (rustaceanvim handles its own LSP client) ────────────────────────────
vim.g.rustaceanvim = {
    server = { on_attach = on_attach },
}
