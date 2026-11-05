-- ── C# / Razor: roslyn.nvim, lazy-loaded ──────────────────────────────────────
-- Required from ftplugin/cs.lua and ftplugin/razor.lua, so it costs nothing until
-- the first C# buffer; require() caching makes it run once per session.
--
-- The server is Microsoft's Roslyn LS (the one VS Code's C# extension uses),
-- installed as a .NET global tool rather than through Mason; see SETUP.md. It
-- needs the .NET SDK (`dotnet`) on PATH to load the solution.

if vim.env.NVIM_SKIP_LSP_CONF then
    return
end

-- `dotnet tool install -g` puts the server here, which isn't on PATH by default.
local tools = vim.fs.normalize('~/.dotnet/tools')
if not vim.env.PATH:find(tools, 1, true) then
    vim.env.PATH = tools .. ':' .. vim.env.PATH
end

vim.pack.add({ 'https://github.com/seblyng/roslyn.nvim' })

vim.lsp.config('roslyn', {
    on_attach = _G.LSP_ON_ATTACH,
    settings = {
        ['csharp|inlay_hints'] = {
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types  = true,
            dotnet_enable_inlay_hints_for_parameters              = true,
        },
        ['csharp|completion'] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
        },
    },
})

require('roslyn').setup({})
