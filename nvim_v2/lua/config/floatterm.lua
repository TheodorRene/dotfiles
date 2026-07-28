-- ── Floating terminal ─────────────────────────────────────────────────────────
-- Stand-in for `:Lspsaga term_toggle`, which is the only feature lspsaga is
-- installed for. Bound to <A-t> in keymaps.lua; lspsaga's <A-d> is still there
-- so the two can be compared side by side.
--
-- Toggling hides the window rather than closing the terminal, so the shell and
-- its scrollback survive across toggles. The buffer is torn down only when the
-- shell itself exits, so the next open starts a fresh session.
--
-- This module is required lazily from the keymap, not at startup.

local M = {}

local state = { buf = nil, win = nil }

local function float_config()
    local width  = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    return {
        relative = 'editor',
        width    = width,
        height   = height,
        row      = math.floor((vim.o.lines - height) / 2) - 1,
        col      = math.floor((vim.o.columns - width) / 2),
        style    = 'minimal',
        -- border is inherited from 'winborder'
    }
end

local function is_open()
    return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function cleanup()
    if is_open() then
        pcall(vim.api.nvim_win_close, state.win, true)
    end
    state.win = nil
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end
    state.buf = nil
end

local function open()
    local fresh = not (state.buf and vim.api.nvim_buf_is_valid(state.buf))
    if fresh then
        state.buf = vim.api.nvim_create_buf(false, true)
    end

    state.win = vim.api.nvim_open_win(state.buf, true, float_config())
    -- Terminals read better against the normal background than NormalFloat.
    vim.wo[state.win].winhighlight = 'NormalFloat:Normal'

    if fresh then
        -- 0.12: jobstart({ term = true }) is the current form of termopen().
        vim.fn.jobstart({ vim.o.shell }, {
            term    = true,
            on_exit = function()
                vim.schedule(cleanup)
            end,
        })
    end

    vim.cmd('startinsert')
end

function M.toggle()
    if is_open() then
        -- win_hide keeps the buffer (and the running shell) alive.
        vim.api.nvim_win_hide(state.win)
        state.win = nil
        return
    end
    open()
end

-- Keep the float centred when the terminal is resized. Registered on first use
-- rather than at startup, since this module is loaded lazily.
vim.api.nvim_create_autocmd('VimResized', {
    group = vim.api.nvim_create_augroup('floatterm_resize', { clear = true }),
    desc  = 'Re-centre the floating terminal on resize',
    callback = function()
        if is_open() then
            vim.api.nvim_win_set_config(state.win, float_config())
        end
    end,
})

return M
