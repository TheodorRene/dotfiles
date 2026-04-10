-- ── Diagnostics (Neovim 0.12) ─────────────────────────────────────────────────
-- BREAKING CHANGE in 0.12: diagnostic signs can NO LONGER be configured with
-- :sign-define or sign_define(). Must use vim.diagnostic.config() signs.text.

local sev = vim.diagnostic.severity

vim.diagnostic.config({
    severity_sort = true,
    update_in_insert = false,

    -- Virtual lines: show diagnostics as virtual text on the current line only.
    -- Keeps the buffer readable while still surfacing errors inline.
    virtual_lines = { current_line = true },

    float = {
        border = 'rounded',
        source = true,   -- show which LSP server reported the diagnostic
    },

    -- Signs in the gutter (0.12 required format — no :sign-define)
    signs = {
        text = {
            [sev.ERROR] = '',
            [sev.WARN]  = '',
            [sev.INFO]  = '',
            [sev.HINT]  = '',
        },
    },
})
