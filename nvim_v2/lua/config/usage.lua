-- ── Keybinding usage tracking ──────────────────────────────────────────────────
-- Answers "which of my custom keybindings do I actually use?" by counting how
-- often each mapping fires. It does NOT log typed text — only records that a
-- mapping you defined was triggered (keyed by mode + lhs), so there is no
-- keylogger-style privacy footprint.
--
-- Mechanism: monkeypatch vim.keymap.set (must load FIRST, before any mapping is
-- defined) and wrap each rhs so triggering it bumps a counter. Counts persist to
-- stdpath('data')/keymap-usage.json and accumulate across sessions. Definitions
-- are re-derived every session (nothing is lazy-loaded), so :KeymapStats can also
-- list bindings that have never fired.
--
-- Provenance: patching vim.keymap.set catches EVERY mapping created at runtime,
-- including Neovim's own LSP defaults (K) and plugin buffer-local maps (j/k
-- inside neo-tree, <Tab> in blink). Counting those together with your own
-- bindings answers the wrong question, so each mapping records the file that
-- defined it and :KeymapStats reports only maps from this config by default.
--
-- Inspect with :KeymapStats (own maps) or :KeymapStats! (everything).

local M = {}

local data_file = vim.fn.stdpath('data') .. '/keymap-usage.json'

-- Persisted usage: key = "<mode> <lhs>" → { n, lhs, mode, desc, src, own }
local counts = {}
-- Session definitions (deduped): key = "<mode> <lhs>" → { lhs, mode, desc, src, own }
local defined = {}
-- "<triggered mode char> <lhs>" → own?, used only to backfill records written
-- before `own` existed. Keyed by mode as well as lhs: a visual-mode K of your
-- own must not mark Neovim's normal-mode K (hover) as yours.
local own_lhs = {}
local dirty = false

-- Resolved so the ~/.config/nvim symlink into this repo still matches.
local CONFIG_ROOT = vim.fn.resolve(vim.fn.stdpath('config'))

-- ── Load prior counts ──────────────────────────────────────────────────────────
do
    local f = io.open(data_file, 'r')
    if f then
        local raw = f:read('*a')
        f:close()
        local ok, decoded = pcall(vim.json.decode, raw)
        if ok and type(decoded) == 'table' then counts = decoded end
    end
end

local function bump(lhs, desc, src, own)
    local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
    local key = mode .. ' ' .. lhs
    local rec = counts[key]
    if not rec then
        rec = { n = 0, lhs = lhs, mode = mode, desc = desc }
        counts[key] = rec
    end
    rec.n = rec.n + 1
    if desc and desc ~= '' then rec.desc = desc end
    rec.src, rec.own = src, own
    dirty = true
end

-- Faithfully replay a string rhs with noremap so mapping semantics (ranges,
-- <Cmd>, visual '<,'> marks) are preserved exactly. noremap ('n') means the fed
-- keys don't re-trigger this wrapper, so there is no recursion.
local function replay(rhs)
    local keys = vim.api.nvim_replace_termcodes(rhs, true, true, true)
    vim.api.nvim_feedkeys(keys, 'n', false)
end

-- Record a definition for the "never fired" report (dedup by mode+lhs).
-- mode() reports a single char at trigger time; a declared mode can produce
-- several (visual is v/V/<C-v>), and operator-pending reports 'n'.
local TRIGGER_MODES = {
    n = { 'n' },              o = { 'n' },
    x = { 'v', 'V', '\22' }, v = { 'v', 'V', '\22', 's' },
    s = { 's' },              i = { 'i' },
    c = { 'c' },              t = { 't' },
    [''] = { 'n', 'v', 'V', '\22' },
}

local function record_def(mode, lhs, desc, src, own)
    defined[mode .. ' ' .. lhs] = { lhs = lhs, mode = mode, desc = desc, src = src, own = own }
    for _, m in ipairs(TRIGGER_MODES[mode] or { mode }) do
        local k = m .. ' ' .. lhs
        own_lhs[k] = own_lhs[k] or own
    end
end

-- Which file called vim.keymap.set. Level 3 skips this function and the wrapper,
-- landing on the caller — which for the local map()/nmap()/bmap() helpers is
-- still the config file that defines them, exactly what we want.
local function caller()
    local info = debug.getinfo(3, 'S')
    local src = info and info.source or ''
    if src:sub(1, 1) ~= '@' then return nil, false end   -- C function or a string chunk
    local path = vim.fn.resolve(src:sub(2))
    return path, path:sub(1, #CONFIG_ROOT) == CONFIG_ROOT
end

-- ── Patch vim.keymap.set ────────────────────────────────────────────────────────
local orig_set = vim.keymap.set
vim.keymap.set = function(mode, lhs, rhs, opts)
    opts = opts or {}
    local desc = opts.desc
    local modes = type(mode) == 'table' and mode or { mode }
    local src, own = caller()
    for _, m in ipairs(modes) do record_def(m, lhs, desc, src, own) end

    local wrapped = rhs
    if type(rhs) == 'function' then
        -- Preserves return value, so expr-function mappings still work.
        wrapped = function(...)
            bump(lhs, desc, src, own)
            return rhs(...)
        end
    elseif type(rhs) == 'string' and not opts.expr then
        -- <Cmd>…<CR> and plain :…<CR> (no visual range) run silently via vim.cmd.
        local ex = rhs:match('^%s*<[Cc][Mm][Dd]>(.-)<[Cc][Rr]>%s*$')
        if not ex then
            local colon = rhs:match('^%s*:(.-)<[Cc][Rr]>%s*$')
            -- Only if it's a single command (no trailing keys, no visual range).
            if colon and not colon:find('<[Cc][Rr]>') and not colon:find("^'<,'>") then
                ex = colon
            end
        end
        if ex then
            wrapped = function()
                bump(lhs, desc, src, own)
                vim.cmd(ex)
            end
        else
            -- Raw key sequences and visual-range commands: replay verbatim.
            wrapped = function()
                bump(lhs, desc, src, own)
                replay(rhs)
            end
        end
    end
    -- expr-string mappings are left untouched (wrapping would change semantics);
    -- they are still listed as defined, just not counted.
    return orig_set(mode, lhs, wrapped, opts)
end

-- ── Persist on exit ──────────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('keymap_usage_persist', { clear = true }),
    callback = function()
        if not dirty then return end
        local f = io.open(data_file, 'w')
        if f then
            f:write(vim.json.encode(counts))
            f:close()
        end
    end,
})

-- ── Viewer ───────────────────────────────────────────────────────────────────────
local MODE_ORDER = { n = 1, v = 2, x = 2, s = 3, o = 4, i = 5, c = 6, t = 7 }

-- The flag stored at trigger time is authoritative — it came from the actual
-- rhs that fired. Only records predating that field fall back to matching this
-- session's definitions on mode + lhs.
local function is_own(rec)
    if rec.own ~= nil then return rec.own end
    return own_lhs[(rec.mode or '') .. ' ' .. rec.lhs] == true
end

-- src is an absolute path; show it relative to the config root for readability.
local function short_src(src)
    if not src then return '' end
    if src:sub(1, #CONFIG_ROOT) == CONFIG_ROOT then
        return src:sub(#CONFIG_ROOT + 2)
    end
    return vim.fn.fnamemodify(src, ':t')
end

vim.api.nvim_create_user_command('KeymapStats', function(opts)
    local all = opts.bang

    local used, used_lhs, skipped = {}, {}, 0
    for _, rec in pairs(counts) do
        if all or is_own(rec) then
            table.insert(used, rec)
        else
            skipped = skipped + 1
        end
        used_lhs[rec.lhs] = true
    end
    table.sort(used, function(a, b) return a.n > b.n end)

    -- Defined but never fired (any mode) — approximate: match on lhs.
    local never = {}
    for _, d in pairs(defined) do
        if (all or d.own) and not used_lhs[d.lhs] then table.insert(never, d) end
    end
    table.sort(never, function(a, b)
        local ma, mb = MODE_ORDER[a.mode] or 9, MODE_ORDER[b.mode] or 9
        if ma ~= mb then return ma < mb end
        return a.lhs < b.lhs
    end)

    local scope = all and 'all mappings, including plugins and built-ins'
                       or 'this config only — :KeymapStats! for everything'
    local lines = {
        '# Keymap usage  (' .. scope .. ')',
        '',
        string.format('%-5s %6s  %-16s %-38s %s', 'mode', 'count', 'lhs', 'desc', 'defined in'),
        string.rep('─', 100),
    }
    for _, r in ipairs(used) do
        table.insert(lines, string.format('%-5s %6d  %-16s %-38s %s',
            r.mode, r.n, r.lhs, r.desc or '', short_src(r.src)))
    end
    if not all and skipped > 0 then
        table.insert(lines, '')
        table.insert(lines, string.format('(%d entries from plugins / built-ins hidden)', skipped))
    end

    table.insert(lines, '')
    table.insert(lines, string.format('# Defined but never fired this session (%d)', #never))
    table.insert(lines, string.rep('─', 100))
    for _, d in ipairs(never) do
        table.insert(lines, string.format('%-5s %6s  %-16s %-38s %s',
            d.mode, '·', d.lhs, d.desc or '', short_src(d.src)))
    end

    vim.cmd('botright new')
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = 'markdown'
end, { bang = true, desc = 'Show keybinding usage counts (! includes plugins)' })

vim.api.nvim_create_user_command('KeymapStatsReset', function()
    counts = {}
    dirty = true
    os.remove(data_file)
    vim.notify('Keymap usage counts reset', vim.log.levels.INFO)
end, { desc = 'Reset keybinding usage counts' })

return M
