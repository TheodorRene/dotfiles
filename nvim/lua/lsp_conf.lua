require("mason").setup()
require("mason-lspconfig").setup()
local nvim_lsp = require('lspconfig')
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
--

vim.cmd [[au FocusGained,BufEnter * :checktime]]
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(_, bufnr)
    --    client.server_capabilities.semanticTokensProvider = nil
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local function opts(desc)
        return {noremap = true, silent = true, desc = desc}
    end
    --
    -- vim.cmd([[
    -- augroup fmt
    -- autocmd! "delete existing autogroup
    -- au BufWritePre * try | undojoin | Neoformat | catch /E790/ | Neoformat | endtry
    -- augroup END
    -- ]])
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>',
                   opts("Declaration"))
    buf_set_keymap('n', 'gd',
                   ':lua require"telescope.builtin".lsp_definitions()<CR>',
                   opts("LSP definitions"))
    -- buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts("Hover"))
    buf_set_keymap("n", "K", "<cmd>Lspsaga hover_doc<CR>", opts("Hover"))
    buf_set_keymap("n", "gh", "<cmd>Lspsaga hover_doc<CR>", opts("Hover"))
    buf_set_keymap('n', 'gi',
                   ':lua require"telescope.builtin".lsp_implementations()<CR>',
                   opts("Implementations"))
    buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>',
                   opts("Signature help"))
    buf_set_keymap('n', '<space>D',
                   '<cmd>lua vim.lsp.buf.type_definition()<CR>',
                   opts("Type defintion"))
    buf_set_keymap('n', '<C-x>d',
                   ':lua require"telescope.builtin".diagnostics()<CR>',
                   opts("Diagnostics"))
    -- buf_set_keymap('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<CR>', opts("Rename"))
    buf_set_keymap('n', '<F2>', '<cmd> Lspsaga rename <CR>', opts("Rename"))
    -- buf_set_keymap('n', '<C-x>c', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts("Code action"))
    buf_set_keymap('n', '<C-x>c', '<cmd>Lspsaga code_action <cr>',
                   opts("Code action"))
    buf_set_keymap('n', '<C-.>', '<cmd>Lspsaga code_action <cr>',
                   opts("Code action"))
    buf_set_keymap('n', '<A-.>', '<cmd>Lspsaga code_action <cr>',
                   opts("Code action"))
    buf_set_keymap('n', '<C-x>r', '<cmd> LspRestart <CR>', opts("Restart LSP"))
    buf_set_keymap('n', 'gr',
                   ':lua require"telescope.builtin".lsp_references()<CR>',
                   opts("References"))
    buf_set_keymap('n', '<C-x>e', '<cmd>lua vim.diagnostic.open_float()<CR>',
                   opts("Open float"))
    buf_set_keymap('n', '<A-e>', '<cmd>lua vim.diagnostic.open_float()<CR>',
                   opts("Open float"))
    -- buf_set_keymap('n', '<C-x>e', '<cmd>Lspsaga show_cursor_diagnostics <CR>',
    --                opts("Open cursor diagnostics"))
    -- buf_set_keymap('n', '<leader>e', '<cmd> Lspsaga show_line_diagnostics <CR>',
    --                opts("Open float"))
    buf_set_keymap('n', '<leader>e', '<cmd> Lspsaga show_line_diagnostics <CR>',
                   opts("Open line diagnostics"))
    buf_set_keymap('n', '<C-x>q', "]d<C-x>c",
                   {noremap = false, silent = true, desc = "Autofix"})
    buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>',
                   opts("Go to next diagnostics"))
    buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>',
                   opts("GO to next diagnostics"))
    buf_set_keymap('v', '<space>fq', ':Neoformat! graphql<CR>',
                   opts("Neoformat"))
    buf_set_keymap('v', '<space>fq', ":'<,'>Neoformat! graphql<CR>",
                   opts("Neoformat"))
    buf_set_keymap('n', '<C-x>t', '<cmd>Lspsaga lsp_finder <CR>',
                   opts("Symbols finder"))
    buf_set_keymap('n', '<C-x>h', '<cmd>lua vim.lsp.codelens.get() <CR>',
                   opts("Symbols finder"))
end

-- require'lspconfig'.lua_ls.setup {
--     settings = {
--         Lua = {
--             runtime = {
--                 -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
--                 version = 'LuaJIT'
--             },
--             diagnostics = {
--                 -- Get the language server to recognize the `vim` global
--                 globals = {'vim'}
--             },
--             workspace = {
--                 -- Make the server aware of Neovim runtime files
--                 library = vim.api.nvim_get_runtime_file("", true)
--             },
--             -- Do not send telemetry data containing a randomized but unique identifier
--             telemetry = {enable = false}
--         }
--     }
-- }
-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = {
    'hls', 'pyright', 'clojure_lsp', 'ts_ls', 'elmls',
    'jdtls', 'eslint', 'lua_ls', 'lemminx', "jsonls", "html"
}
-- Marksman for markdown is nice but I dont want it to be spawned when hovering in typescript
-- Maybe fix that some time. If in typescript dont spawn marksman
for _, lsp in ipairs(servers) do
    nvim_lsp[lsp].setup {
        on_attach = on_attach,
        capabilities = capabilities,
        flags = {debounce_text_changes = 150}
    }
end

-- nvim_lsp['hls'].setup {
--     on_attach = on_attach,
--     capabilities = capabilities,
--     flags = {debounce_text_changes = 150},
--     filetypes = { 'haskell', 'lhaskell', 'cabal' },
-- }

local rt = require("rust-tools")

rt.setup({server = {on_attach = on_attach}})

nvim_lsp.clangd.setup {
    -- cmd = { 'clangd-12' };
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {debounce_text_changes = 150}
}

local cmp = require 'cmp'
local lspkind = require 'lspkind'

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'
cmp.setup {
    snippet = {
        -- REQUIRED - you must specify a snippet engine
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
            -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
            -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
            -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
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
        {name = 'nvim_lsp'}, {name = 'buffer'}, {name = 'vim-dadbod-completion'}
    },
    formatting = {
        format = lspkind.cmp_format({
            mode = 'symbol-text', -- show only symbol annotations
            maxwidth = 50 -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
        })
    }
}

