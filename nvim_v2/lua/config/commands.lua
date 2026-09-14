-- ── User commands ─────────────────────────────────────────────────────────────
-- All require() calls are direct — no lazy.nvim load() shims needed.
local cmd = vim.api.nvim_create_user_command

-- ── File / build ─────────────────────────────────────────────────────────────
cmd('Rocaf', ':!rocaf %', { desc = 'Run rocaf on current file' })

cmd('CopyFilename', function()
    vim.fn.setreg('+', vim.fn.expand('%:p'))
    vim.notify('Copied: ' .. vim.fn.expand('%:p'))
end, { desc = 'Copy absolute file path to clipboard' })

cmd('Reminder', ':e ~/dev/reminder_for_tomorrow.md', { desc = 'Open reminder file' })

-- Open this week's Impero note; seeds from last week's note if missing.
-- weekly-note.rb prints the note path on stdout (diagnostics go to stderr).
cmd('Week', function()
    local script = vim.fn.expand('~/dotfiles/scripts/weekly-note.rb')
    local res = vim.system({ 'ruby', script }, { text = true }):wait()
    if res.code ~= 0 then
        local msg = vim.trim(res.stderr or '')
        vim.notify('Week: ' .. (msg ~= '' and msg or 'failed to resolve note'), vim.log.levels.ERROR)
        return
    end
    local path = vim.trim(res.stdout or '')
    if path == '' then
        vim.notify('Week: script returned no path', vim.log.levels.ERROR)
        return
    end
    vim.cmd.tabedit(vim.fn.fnameescape(path))
end, { desc = "Open this week's Impero note (weekly-note.rb)" })

cmd('Dotfiles', function()
    require('fzf-lua').files({ cwd = '~/dotfiles' })
end, { desc = 'FZF: browse dotfiles' })

-- ── Navigation ───────────────────────────────────────────────────────────────
-- nargs=1 rather than '*' so a bare :ChangeDir errors instead of silently
-- jumping home (see 'cdh' in options.lua); complete=dir gives path completion.
cmd('ChangeDir', function(args)
    vim.cmd.chdir(args.args)
end, { nargs = 1, complete = 'dir', desc = 'Change global directory' })

-- Fuzzy-pick a directory from autojump's frecency database. The shell already
-- maintains it (sourced in .zshrc), so the ranking reflects where work actually
-- happens — no extra dependency and no separate list to curate.
--
-- <enter> opens the directory in a NEW TAB with a tab-local cwd, so sibling
-- projects (impero frontend + backend, say) can be open simultaneously without
-- their pickers bleeding into each other. 'tcd' is per-tab, and fzf-lua reads
-- the window's cwd, so each tab searches its own project. Note LSP roots come
-- from root_markers, not cwd, so switching here never strands a client.
local AUTOJUMP_DB = vim.fn.expand('~/.local/share/autojump/autojump.txt')

-- Rows are "<weight>\t<path>", unsorted. Stale paths are dropped so the picker
-- never offers a directory that has since been deleted or moved.
local function autojump_dirs()
    local fh = io.open(AUTOJUMP_DB, 'r')
    if not fh then return nil end
    local rows = {}
    for line in fh:lines() do
        local weight, path = line:match('^([%d%.eE%+%-]+)\t(.+)$')
        if path and vim.fn.isdirectory(path) == 1 then
            table.insert(rows, { w = tonumber(weight) or 0, path = path })
        end
    end
    fh:close()
    table.sort(rows, function(a, b) return a.w > b.w end)
    local out = {}
    for _, r in ipairs(rows) do
        table.insert(out, vim.fn.fnamemodify(r.path, ':~'))
    end
    return out
end

local function switch_to(display, how)
    local path = vim.fn.expand(display)
    if vim.fn.isdirectory(path) == 0 then
        vim.notify('Dirs: no longer a directory: ' .. path, vim.log.levels.ERROR)
        return
    end
    if how == 'tabnew' then
        vim.cmd.tabnew()
        vim.cmd.tcd(path)
    elseif how == 'tcd' then
        vim.cmd.tcd(path)
    else
        vim.cmd.chdir(path)
    end
    local scope = how == 'chdir' and 'cwd' or 'tab cwd'
    vim.notify(scope .. ' → ' .. vim.fn.fnamemodify(path, ':~'), vim.log.levels.INFO)
end

cmd('Dirs', function()
    local dirs = autojump_dirs()
    if not dirs or #dirs == 0 then
        vim.notify('Dirs: no usable autojump database at ' .. AUTOJUMP_DB, vim.log.levels.WARN)
        return
    end
    local ok, fzf = pcall(require, 'fzf-lua')
    if not ok then
        vim.notify('Dirs: fzf-lua not available', vim.log.levels.ERROR)
        return
    end
    local function act(how)
        return function(sel) if sel and sel[1] then switch_to(sel[1], how) end end
    end
    fzf.fzf_exec(dirs, {
        prompt    = 'Dir❯ ',
        fzf_opts  = {
            ['--header'] = 'enter: new tab   alt-c: this tab   alt-g: global cd',
        },
        actions = {
            ['default'] = act('tabnew'),
            ['alt-c']   = act('tcd'),
            ['alt-g']   = act('chdir'),
        },
    })
end, { desc = 'Switch directory (autojump frecency)' })

-- Dump session state for an AI assistant when something misbehaves. Lazily
-- required so it costs nothing at startup. See lua/config/debugai.lua.
cmd('DebugAI', function(args)
    require('config.debugai').dump(args.args, args.bang)
end, { nargs = '*', bang = true, desc = 'Write a debug report for an AI assistant' })

-- ── LSP helpers ───────────────────────────────────────────────────────────────
cmd('Hover', function()
    vim.lsp.buf.hover()
end, { desc = 'LSP hover' })

cmd('Rename', function()
    vim.lsp.buf.rename()
end, { desc = 'LSP rename' })

cmd('CodeAction', function()
    vim.lsp.buf.code_action()
end, { desc = 'LSP code action' })

cmd('LspInfo', ':checkhealth vim.lsp', { desc = 'LSP healthcheck' })

-- :LspRestart is NOT a Neovim built-in (it came from nvim-lspconfig), so the
-- <C-x>r keymap in lsp.lua needs it defined here.
--
-- vim.lsp.enable() autostarts servers from a FileType autocmd in the
-- nvim.lsp.enable augroup, so firing that group again is what re-attaches —
-- no :edit and no reload, which means unsaved changes are safe.
cmd('LspRestart', function()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Only touch clients that vim.lsp.enable() owns. Copilot starts its own
    -- client on its own triggers, so stopping it here would just leave it down.
    local clients = vim.tbl_filter(function(c)
        local ok, enabled = pcall(vim.lsp.is_enabled, c.name)
        return ok and enabled
    end, vim.lsp.get_clients({ bufnr = bufnr }))

    if #clients == 0 then
        vim.notify('LspRestart: no restartable clients attached to this buffer',
            vim.log.levels.WARN)
        return
    end

    local names = vim.tbl_map(function(c) return c.name end, clients)
    for _, client in ipairs(clients) do
        client:stop()
    end

    -- Wait for the old clients to exit, otherwise vim.lsp.start reuses them.
    local stopped_ids = vim.tbl_map(function(c) return c.id end, clients)
    local stopped = vim.wait(3000, function()
        for _, id in ipairs(stopped_ids) do
            if vim.lsp.get_client_by_id(id) then return false end
        end
        return true
    end, 50)

    vim.cmd('doautocmd nvim.lsp.enable FileType')

    if stopped then
        vim.notify('LspRestart: ' .. table.concat(names, ', '))
    else
        vim.notify('LspRestart: timed out waiting for ' .. table.concat(names, ', '),
            vim.log.levels.WARN)
    end
end, { desc = 'Restart LSP clients attached to this buffer' })

-- ── Treesitter ────────────────────────────────────────────────────────────────
cmd('ResetTS', function()
    vim.cmd('write | edit')
    local ok, _ = pcall(vim.treesitter.start, 0)
    if not ok then
        vim.notify('ResetTS: no treesitter parser for this filetype', vim.log.levels.WARN)
    end
end, { desc = 'Reset Treesitter highlighting' })

-- ── Git ───────────────────────────────────────────────────────────────────────
cmd('AddFile', ':Git add %',  { desc = 'Git add current file' })
cmd('OpenPr',  ':!git prview', { desc = 'Open PR in browser' })
cmd('OpenJira', ':!git jira',  { desc = 'Open Jira ticket for branch' })

cmd('DiffLastCommit', function()
    require('neogit').open({ 'diff', 'HEAD^' })
end, { desc = 'Diff vs last commit (neogit)' })

cmd('StageHunk', function()
    require('gitsigns').stage_hunk()
end, { desc = 'Gitsigns: stage hunk' })

cmd('UndoStageHunk', function()
    require('gitsigns').undo_stage_hunk()
end, { desc = 'Gitsigns: undo stage hunk' })

cmd('ResetHunk', function()
    require('gitsigns').reset_hunk()
end, { desc = 'Gitsigns: reset hunk' })

cmd('PreviewHunk', function()
    require('gitsigns').preview_hunk()
end, { desc = 'Gitsigns: preview hunk' })

cmd('BlameLine', function()
    require('gitsigns').blame_line({ full = true })
end, { desc = 'Gitsigns: blame line' })

cmd('ResetCurrentLine', function()
    require('gitsigns').reset_hunk({ vim.fn.line('.'), vim.fn.line('.') })
end, { desc = 'Gitsigns: reset current line' })

cmd('GitResetCurrentLine', function()
    vim.cmd('.!git checkout -- ' .. vim.fn.shellescape(vim.fn.expand('%')) .. ':' .. vim.fn.line('.'))
end, { desc = 'Git checkout current line from index' })

-- ── Editing helpers ───────────────────────────────────────────────────────────
cmd('Fold', function()
    vim.cmd('normal zA')
end, { desc = 'Toggle fold' })

cmd('Scrollbind', function()
    vim.cmd('windo set scrollbind!')
end, { desc = 'Toggle scrollbind on all windows' })

cmd('Uniq', ':uniq', { desc = 'Deduplicate lines in buffer (0.12 built-in)' })

cmd('CopyAI', function(opts)
    local path   = vim.fn.expand('%:p')
    local lines  = vim.fn.getline(opts.line1, opts.line2)
    local header = path .. ':' .. opts.line1 .. '-' .. opts.line2
    vim.fn.setreg('+', header .. '\n' .. table.concat(lines, '\n'))
    vim.notify('Copied ' .. opts.line1 .. '-' .. opts.line2 .. ' → clipboard', vim.log.levels.INFO)
end, { range = true, desc = 'Copy selection with file path for AI' })
