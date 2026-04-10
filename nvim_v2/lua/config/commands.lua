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

cmd('Dotfiles', function()
    require('fzf-lua').files({ cwd = '~/dotfiles' })
end, { desc = 'FZF: browse dotfiles' })

-- ── Navigation ───────────────────────────────────────────────────────────────
cmd('ChangeDir', function(args)
    vim.cmd('chdir ' .. args.args)
end, { nargs = '*', desc = 'Change directory' })

-- ── LSP helpers ───────────────────────────────────────────────────────────────
cmd('Hover', function()
    vim.lsp.buf.hover({ border = 'rounded' })
end, { desc = 'LSP hover' })

cmd('Rename', function()
    vim.lsp.buf.rename()
end, { desc = 'LSP rename' })

cmd('CodeAction', function()
    vim.lsp.buf.code_action()
end, { desc = 'LSP code action' })

cmd('LspInfo', ':checkhealth vim.lsp', { desc = 'LSP healthcheck' })

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
