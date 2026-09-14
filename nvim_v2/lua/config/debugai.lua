-- ── :DebugAI — dump session state for an AI assistant to read ────────────────
-- Built for intermittent bugs: the kind where by the time you describe it, the
-- state that would have explained it is gone. Run :DebugAI the moment something
-- misbehaves and hand over the path.
--
-- Captures what actually turned out to be load-bearing while debugging a
-- "grr does nothing" report: which keys are mapped and by whom (which-key
-- installs buffer-local triggers on g and <Space> that swallow those prefixes),
-- the attached LSP clients and their roots, and :messages — which matters
-- because cmdheight=0 + ui2 means a thrown error has nowhere visible to land.
--
-- Output goes to stdpath('state')/debug-ai/, never into the dotfiles repo:
-- it contains absolute paths, buffer names and message text, which on a public
-- repo would leak project and customer identifiers. A copy is always written to
-- latest.md so the assistant can read it without being told the timestamp.
--
--   :DebugAI                  → report + note-less
--   :DebugAI grr did nothing  → same, with your description at the top
--   :DebugAI!                 → also appends the tail of the LSP log
--
-- This module is required lazily from the command, not at startup.

local M = {}

local OUT_DIR = vim.fn.stdpath('state') .. '/debug-ai'

-- Keys worth probing: everything under a which-key trigger prefix, plus a few
-- bare keys as controls. If a bare key works and a prefixed one doesn't, the
-- trigger layer is the suspect rather than LSP.
local PROBE = {
    { 'g',   'n', 'which-key trigger prefix' },
    { ' ',   'n', 'leader / which-key trigger prefix' },
    { 'K',   'n', 'control: bare key, no prefix' },
    { 'grr', 'n', 'LSP references' },
    { 'gd',  'n', 'LSP definitions' },
    { 'gi',  'n', 'LSP implementations' },
    { 'gD',  'n', 'LSP declaration' },
    { 'grn', 'n', '0.12 default rename' },
    { 'gra', 'n', '0.12 default code action' },
    { ' f',  'n', 'format (conform)' },
    { ' d',  'n', ':Dirs' },
    { ' e',  'n', 'neo-tree' },
    { ' D',  'n', 'LSP type definition' },
    { '<C-p>', 'n', 'fff find_files' },
}

-- Every section is guarded: a failure in one must not cost us the whole report.
local function section(out, title, fn)
    out[#out + 1] = ''
    out[#out + 1] = '## ' .. title
    out[#out + 1] = ''
    local ok, err = pcall(fn, out)
    if not ok then
        out[#out + 1] = '_section failed: ' .. tostring(err) .. '_'
    end
end

local function session(out)
    local v = vim.version()
    out[#out + 1] = ('- nvim: %d.%d.%d'):format(v.major, v.minor, v.patch)
    out[#out + 1] = '- uis attached: ' .. #vim.api.nvim_list_uis()
    out[#out + 1] = '- global cwd: ' .. vim.fn.getcwd(-1, -1)
    out[#out + 1] = '- tab cwd: ' .. vim.fn.getcwd()
    out[#out + 1] = '- buffer: ' .. (vim.api.nvim_buf_get_name(0) ~= '' and vim.api.nvim_buf_get_name(0) or '(none)')
    out[#out + 1] = ('- filetype=%s buftype=%s mode=%s'):format(
        vim.bo.filetype ~= '' and vim.bo.filetype or '(none)',
        vim.bo.buftype ~= '' and vim.bo.buftype or '(normal)',
        vim.api.nvim_get_mode().mode)
    out[#out + 1] = ('- timeoutlen=%d cmdheight=%d'):format(vim.o.timeoutlen, vim.o.cmdheight)
    -- Recording state is load-bearing: which-key suspends ALL of its triggers
    -- while a macro records or executes (util.lua in_macro + triggers.lua), and
    -- with cmdheight=0 the "recording @q" indicator has nowhere to appear — so
    -- you can sit in this state indefinitely with no visual cue.
    local rec, exe = vim.fn.reg_recording(), vim.fn.reg_executing()
    out[#out + 1] = ('- **reg_recording=%s reg_executing=%s**%s'):format(
        rec ~= '' and ('@' .. rec) or 'no',
        exe ~= '' and ('@' .. exe) or 'no',
        (rec ~= '' or exe ~= '') and '  ← which-key triggers are suspended by this' or '')
    out[#out + 1] = '- NVIM_SKIP_LSP_CONF: ' .. tostring(vim.env.NVIM_SKIP_LSP_CONF ~= nil)
end

local function clients(out)
    local buf = vim.lsp.get_clients({ bufnr = 0 })
    local all = vim.lsp.get_clients()
    if #all == 0 then
        out[#out + 1] = '**No LSP clients running at all.**'
        return
    end
    out[#out + 1] = '| client | id | attached here | initialized | root_dir |'
    out[#out + 1] = '|---|---|---|---|---|'
    local here = {}
    for _, c in ipairs(buf) do here[c.id] = true end
    for _, c in ipairs(all) do
        out[#out + 1] = ('| %s | %d | %s | %s | %s |'):format(
            c.name, c.id, here[c.id] and 'yes' or 'no',
            tostring(c.initialized), tostring(c.root_dir))
    end
end

local function keymaps(out)
    out[#out + 1] = '`[buf]` = buffer-local. A which-key trigger on a prefix'
    out[#out + 1] = 'intercepts every mapping beneath it.'
    out[#out + 1] = ''
    out[#out + 1] = '| key | resolves to | scope | note |'
    out[#out + 1] = '|---|---|---|---|'
    for _, p in ipairs(PROBE) do
        local lhs, mode, note = p[1], p[2], p[3]
        local r = vim.fn.maparg(lhs, mode, 0, 1)
        local desc
        if vim.tbl_isempty(r) then
            desc = '**NO MAPPING**'
        else
            desc = r.desc or (r.rhs ~= '' and r.rhs) or '(no desc)'
        end
        out[#out + 1] = ('| `%s` | %s | %s | %s |'):format(
            lhs == ' ' and '<Space>' or lhs, desc,
            vim.tbl_isempty(r) and '-' or (r.buffer == 1 and 'buf' or 'global'), note)
    end
end

local function whichkey(out)
    local ok, wk = pcall(require, 'which-key')
    out[#out + 1] = '- require: ' .. tostring(ok)
    if not ok then
        out[#out + 1] = '- error: ' .. tostring(wk)
        return
    end
    -- Deliberately NOT calling wk.show() as a probe: it opens a popup as a side
    -- effect, and it throws whenever which-key has not been UI-initialised
    -- (headless, or before first use), which reads as a failure when nothing is
    -- wrong. Trigger presence is the signal that actually distinguishes the bug.
    local trig = {}
    for _, mode in ipairs({ 'n', 'v', 'x', 'o', 'i' }) do
        for _, scope in ipairs({ 'global', 'buffer' }) do
            local okm, maps = pcall(function()
                return scope == 'global' and vim.api.nvim_get_keymap(mode)
                                          or vim.api.nvim_buf_get_keymap(0, mode)
            end)
            for _, m in ipairs(okm and maps or {}) do
                if m.desc and m.desc:find('which-key-trigger', 1, true) then
                    trig[#trig + 1] = ('`%s` (%s %s)'):format(m.lhs, mode, scope)
                end
            end
        end
    end
    out[#out + 1] = '- trigger mappings: ' .. (#trig > 0 and table.concat(trig, ', ') or '**none**')
    out[#out + 1] = ''
    local in_macro = vim.fn.reg_recording() ~= '' or vim.fn.reg_executing() ~= ''
    if #trig == 0 and in_macro then
        out[#out + 1] = '**Diagnosis: a macro is recording/executing, which is why there are**'
        out[#out + 1] = '**no triggers.** which-key suspends them all for the duration, so no'
        out[#out + 1] = 'popup appears on any prefix. Press `q` to stop recording. Nothing is'
        out[#out + 1] = 'broken — but with cmdheight=0 the recording indicator is invisible.'
    elseif #trig == 0 then
        out[#out + 1] = '**No triggers, and no macro is running** — which-key should have'
        out[#out + 1] = 'attached. Note it installs them via a scheduled timer, so a snapshot'
        out[#out + 1] = 'taken immediately after entering a buffer can race it.'
    else
        out[#out + 1] = 'If a prefix above has a trigger but the mapping under it does nothing,'
        out[#out + 1] = 'which-key ate the key. Bare keys like `K` bypass the trigger layer, so'
        out[#out + 1] = 'bare-works/prefixed-fails points at which-key rather than LSP.'
    end
end

local function diagnostics(out)
    local d = vim.diagnostic.get(0)
    out[#out + 1] = '- diagnostics in buffer: ' .. #d
    out[#out + 1] = '- v:errmsg: ' .. (vim.v.errmsg ~= '' and vim.v.errmsg or '(empty)')
end

local function messages(out)
    local msg = vim.api.nvim_exec2('messages', { output = true }).output or ''
    if msg == '' then
        out[#out + 1] = '_(empty — note that cmdheight=0 + ui2 can hide errors from view,'
        out[#out + 1] = 'but they would still appear here)_'
        return
    end
    local lines = vim.split(msg, '\n', { plain = true })
    local from = math.max(1, #lines - 99)
    out[#out + 1] = '```'
    for i = from, #lines do out[#out + 1] = lines[i] end
    out[#out + 1] = '```'
end

local function lsp_log(out)
    local path = vim.lsp.log.get_filename()
    out[#out + 1] = '- path: ' .. tostring(path)
    local fh = io.open(path, 'r')
    if not fh then
        out[#out + 1] = '_(not readable)_'
        return
    end
    local all = {}
    for line in fh:lines() do all[#all + 1] = line end
    fh:close()
    out[#out + 1] = '```'
    for i = math.max(1, #all - 59), #all do out[#out + 1] = (all[i] or ''):sub(1, 400) end
    out[#out + 1] = '```'
end

--- Write the report. `note` is free text describing what just went wrong;
--- `with_log` appends the tail of the LSP log.
function M.dump(note, with_log)
    vim.fn.mkdir(OUT_DIR, 'p')

    local out = {
        '# nvim DebugAI report',
        '',
        '- generated: ' .. os.date('%Y-%m-%d %H:%M:%S'),
        '- note: ' .. ((note and note ~= '') and note or '_(none given)_'),
    }

    section(out, 'Session',      session)
    section(out, 'LSP clients',  clients)
    section(out, 'Keymaps',      keymaps)
    section(out, 'which-key',    whichkey)
    section(out, 'Diagnostics',  diagnostics)
    section(out, 'Messages',     messages)
    if with_log then section(out, 'LSP log (tail)', lsp_log) end

    local body = table.concat(out, '\n') .. '\n'
    local stamp = os.date('%Y%m%d-%H%M%S')
    local path  = ('%s/%s.md'):format(OUT_DIR, stamp)

    for _, target in ipairs({ path, OUT_DIR .. '/latest.md' }) do
        local fh, err = io.open(target, 'w')
        if not fh then
            vim.notify('DebugAI: cannot write ' .. target .. ': ' .. tostring(err), vim.log.levels.ERROR)
            return
        end
        fh:write(body)
        fh:close()
    end

    pcall(vim.fn.setreg, '+', path)
    vim.notify('DebugAI → ' .. path .. '\n(also latest.md; path copied)', vim.log.levels.INFO)
    return path
end

return M
